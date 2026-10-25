// navgen: headless bot navmesh generator for Natural Selection.
//
// Does what GoldsrcNavEditor.exe's "Input Map" -> "Build" -> "Save" does, from
// the command line, and writes the .nav layout the NS bots load
// (TileCacheBuildHeader in src/main/source/mod/AvHAINavigation.cpp):
//
//   navgen build <map.bsp> <out.nav> [options]
//   navgen dump <file.nav>           per-tile fingerprint, for comparing files
//   navgen tile <file.nav> <mesh> <tx> <ty> <layer>   one tile layer as text
//
// The geometry loader (BSP -> triangles + surface types) and the Recast build
// come from RGreenlees/goldsrcnaveditor, the source of the NS editor. A .nav
// holds only the compressed heightfield layers of each tile; the bots build
// the polygons when they load it. So only rasterization, filtering, erosion
// and area marking decide the file content, which is what this reproduces.
// The three NS meshes and their settings are the ones stored in the headers
// of .nav files saved by NS's editor (see kMeshes).

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "ChunkyTriMesh.h"
#include "DetourAlloc.h"
#include "DetourCommon.h"
#include "DetourTileCacheBuilder.h"
#include "MeshLoaderObj.h"
#include "Recast.h"
#include "fastlz.h"

// ---------------------------------------------------------------------------
// NS file format. These mirror NS's runtime structs, which differ from the
// editor's current ones (its dtTileCacheParams gained crouchHeight).

static const int kTileCacheSetMagic = 'T' << 24 | 'S' << 16 | 'E' << 8 | 'T';
static const int kTileCacheSetVersion = 2;

struct NsNavMeshParams
{
	float orig[3];
	float tileWidth, tileHeight;
	int maxTiles, maxPolys;
};

struct NsTileCacheParams
{
	float orig[3];
	float cs, ch;
	int width, height;
	float walkableHeight, walkableRadius, walkableClimb, walkableSlope;
	float maxSimplificationError;
	int maxTiles, maxObstacles, maxOffMeshConnections;
};

struct NsMeshHeader
{
	NsNavMeshParams mesh;
	NsTileCacheParams cache;
};

struct NsFileHeader
{
	int magic, version;
	int numTiles[3]; // regular, onos, building
	NsMeshHeader meshes[3];
	int NumSurfTypes, SurfTypesOffset;
	int NumOffMeshCons, OffMeshConsOffset;
	int NumConvexVols, ConvexVolOffset;
	int NumNavHints, NavHintOffset;
};

struct NsTileHeader
{
	unsigned int tileRef;
	int dataSize;
};

static_assert(sizeof(NsFileHeader) == 316, "NS .nav header layout");

// ---------------------------------------------------------------------------
// Build settings

struct MeshDef
{
	const char* name;
	float standHeight, radius, maxStep, maxSlope;
};

// From the headers of .nav files saved by NS's editor
static const MeshDef kMeshes[3] = {
	{ "regular", 72.0f, 17.0f, 18.0f, 50.0f },
	{ "onos", 108.0f, 32.0f, 18.0f, 50.0f },
	{ "building", 100.0f, 32.0f, 18.0f, 45.0f },
};

struct Options
{
	float cellSize = 3.0f;
	float cellHeight = 3.0f;
	int tileSize = 48;
	float edgeMaxError = 2.0f;
	// Crouch height per mesh (regular, onos, building); not stored in the
	// file. Equal to the standing height means no crouch areas.
	float crouchHeight[3] = { 36.0f, 72.0f, 100.0f };
	// Per mesh (regular, onos, building)
	bool layersUseCrouch[3] = { true, true, true }; // rcBuildHeightfieldLayers gets crouch height
	bool filterLowHanging[3] = { true, true, true };
	bool filterLedges[3] = { false, false, true };
	bool filterLowHeight[3] = { true, true, true };
};


static const int kExpectedLayersPerTile = 4;
static const int kMaxLayers = 32;

// ---------------------------------------------------------------------------
// Tile cache helpers (as in the editor's Sample_TempObstacles.cpp)

struct FastLZCompressor : public dtTileCacheCompressor
{
	int maxCompressedSize(const int bufferSize) override { return (int)(bufferSize * 1.05f); }

	dtStatus compress(const unsigned char* buffer, const int bufferSize,
	                  unsigned char* compressed, const int, int* compressedSize) override
	{
		*compressedSize = fastlz_compress((const void*)buffer, bufferSize, compressed);
		return DT_SUCCESS;
	}

	dtStatus decompress(const unsigned char* compressed, const int compressedSize,
	                    unsigned char* buffer, const int maxBufferSize, int* bufferSize) override
	{
		*bufferSize = fastlz_decompress(compressed, compressedSize, buffer, maxBufferSize);
		return *bufferSize < 0 ? DT_FAILURE : DT_SUCCESS;
	}
};

struct MallocAllocator : public dtTileCacheAlloc
{
	void* alloc(const size_t size) override { return dtAlloc(size, DT_ALLOC_TEMP); }
	void free(void* ptr) override { dtFree(ptr); }
};

struct LayerData
{
	unsigned char* data = nullptr;
	int dataSize = 0;
};

// Rasterize one tile into compressed layers; mirrors the editor's
// Sample_TempObstacles::rasterizeTileLayers (no convex volumes).
static int rasterizeTileLayers(rcContext* ctx, const rcMeshLoaderObj& mesh,
                               const rcChunkyTriMesh& chunky, int m, int tx, int ty,
                               const rcConfig& cfg, const Options& opt,
                               std::vector<LayerData>& out)
{
	FastLZCompressor comp;
	const float* verts = mesh.getVerts();
	const int nverts = mesh.getVertCount();
	const float tcs = cfg.tileSize * cfg.cs;

	rcConfig tcfg = cfg;
	tcfg.bmin[0] = cfg.bmin[0] + tx * tcs;
	tcfg.bmin[1] = cfg.bmin[1];
	tcfg.bmin[2] = cfg.bmin[2] + ty * tcs;
	tcfg.bmax[0] = cfg.bmin[0] + (tx + 1) * tcs;
	tcfg.bmax[1] = cfg.bmax[1];
	tcfg.bmax[2] = cfg.bmin[2] + (ty + 1) * tcs;
	tcfg.bmin[0] -= tcfg.borderSize * tcfg.cs;
	tcfg.bmin[2] -= tcfg.borderSize * tcfg.cs;
	tcfg.bmax[0] += tcfg.borderSize * tcfg.cs;
	tcfg.bmax[2] += tcfg.borderSize * tcfg.cs;

	float tbmin[2] = { tcfg.bmin[0], tcfg.bmin[2] };
	float tbmax[2] = { tcfg.bmax[0], tcfg.bmax[2] };
	int cid[512];
	const int ncid = rcGetChunksOverlappingRect(&chunky, tbmin, tbmax, cid, 512);
	if (!ncid)
		return 0;

	rcHeightfield* solid = rcAllocHeightfield();
	if (!solid || !rcCreateHeightfield(ctx, *solid, tcfg.width, tcfg.height, tcfg.bmin, tcfg.bmax, tcfg.cs, tcfg.ch))
		return -1;

	std::vector<unsigned char> triareas(chunky.maxTrisPerChunk);
	for (int i = 0; i < ncid; ++i)
	{
		const rcChunkyTriMeshNode& node = chunky.nodes[cid[i]];
		const int* tris = &chunky.tris[node.i * 3];
		const int* surfTypes = &chunky.surfTypes[node.i];
		const int ntris = node.n;

		memset(triareas.data(), 0, ntris);
		rcMarkWalkableTriangles(ctx, tcfg.walkableSlopeAngle, verts, nverts, tris, ntris, triareas.data(), surfTypes);
		if (!rcRasterizeTriangles(ctx, verts, nverts, tris, triareas.data(), ntris, *solid, tcfg.walkableClimb))
			return -1;
	}

	if (opt.filterLowHanging[m])
		rcFilterLowHangingWalkableObstacles(ctx, tcfg.walkableClimb, *solid);
	if (opt.filterLedges[m])
		rcFilterLedgeSpans(ctx, tcfg.walkableHeight, tcfg.walkableClimb, *solid);
	if (opt.filterLowHeight[m])
		rcFilterWalkableLowHeightSpans(ctx, tcfg.walkableHeight, cfg.crouchHeight, *solid);

	rcCompactHeightfield* chf = rcAllocCompactHeightfield();
	if (!chf || !rcBuildCompactHeightfield(ctx, 13, tcfg.walkableClimb, *solid, *chf))
		return -1;
	rcFreeHeightField(solid);

	if (!rcErodeWalkableArea(ctx, tcfg.walkableRadius, *chf))
		return -1;

	rcHeightfieldLayerSet* lset = rcAllocHeightfieldLayerSet();
	const int layerHeight = opt.layersUseCrouch[m] ? cfg.crouchHeight : tcfg.walkableHeight;
	if (!lset || !rcBuildHeightfieldLayers(ctx, *chf, tcfg.borderSize, layerHeight, *lset))
		return -1;
	rcFreeCompactHeightfield(chf);

	int n = 0;
	for (int i = 0; i < rcMin(lset->nlayers, kMaxLayers); ++i)
	{
		const rcHeightfieldLayer* layer = &lset->layers[i];

		// The editor's current Recast marks areas by its game profiles
		// (1 walk, 2 crouch); NS uses the fixed codes of its own editor
		// (RC_WALKABLE_AREA 63 walk, DT_TILECACHE_CROUCH_AREA 1 crouch).
		const int cells = layer->width * layer->height;
		for (int c = 0; c < cells; ++c)
		{
			if (layer->areas[c] == 1)
				layer->areas[c] = RC_WALKABLE_AREA;
			else if (layer->areas[c] == 2)
				layer->areas[c] = RC_CROUCH_AREA;
		}

		dtTileCacheLayerHeader header;
		header.magic = DT_TILECACHE_MAGIC;
		header.version = DT_TILECACHE_VERSION;
		header.tx = tx;
		header.ty = ty;
		header.tlayer = i;
		dtVcopy(header.bmin, layer->bmin);
		dtVcopy(header.bmax, layer->bmax);
		header.width = (unsigned char)layer->width;
		header.height = (unsigned char)layer->height;
		header.minx = (unsigned char)layer->minx;
		header.maxx = (unsigned char)layer->maxx;
		header.miny = (unsigned char)layer->miny;
		header.maxy = (unsigned char)layer->maxy;
		header.hmin = (unsigned short)layer->hmin;
		header.hmax = (unsigned short)layer->hmax;

		LayerData ld;
		if (dtStatusFailed(dtBuildTileCacheLayer(&comp, &header, layer->heights, layer->areas, layer->cons,
		                                         &ld.data, &ld.dataSize)))
			return -1;
		out.push_back(ld);
		n++;
	}
	rcFreeHeightfieldLayerSet(lset);
	return n;
}

static int cmdBuild(const char* bspPath, const char* outPath, const Options& opt)
{
	rcContext ctx(false);

	// The editor's loader doesn't validate its input
	FILE* bsp = fopen(bspPath, "rb");
	int bspVersion = 0;
	if (!bsp || fread(&bspVersion, sizeof(bspVersion), 1, bsp) != 1 || bspVersion != 30)
	{
		fprintf(stderr, "error: %s is not a GoldSrc (v30) BSP\n", bspPath);
		if (bsp)
			fclose(bsp);
		return 1;
	}
	fclose(bsp);

	rcMeshLoaderObj mesh;
	if (!mesh.loadBSP(bspPath))
	{
		fprintf(stderr, "error: could not load %s\n", bspPath);
		return 1;
	}
	if (!mesh.getTriCount())
	{
		fprintf(stderr, "error: %s has no geometry\n", bspPath);
		return 1;
	}

	rcChunkyTriMesh chunky;
	if (!rcCreateChunkyTriMesh(mesh.getVerts(), mesh.getTris(), mesh.getTriCount(), 256, &chunky, mesh.getSurfaceTypes()))
	{
		fprintf(stderr, "error: could not build chunky mesh\n");
		return 1;
	}

	float bmin[3], bmax[3];
	rcCalcBounds(mesh.getVerts(), mesh.getVertCount(), bmin, bmax);

	int gw = 0, gh = 0;
	rcCalcGridSize(bmin, bmax, opt.cellSize, &gw, &gh);
	const int ts = opt.tileSize;
	const int tw = (gw + ts - 1) / ts;
	const int th = (gh + ts - 1) / ts;

	const int cacheMaxTiles = tw * th * kExpectedLayersPerTile;
	const int tileBits = rcMin((int)dtIlog2(dtNextPow2(cacheMaxTiles)), 14);
	const int polyBits = 22 - tileBits;
	const int cacheTileBits = (int)dtIlog2(dtNextPow2((unsigned int)cacheMaxTiles));

	NsFileHeader header;
	memset(&header, 0, sizeof(header));
	header.magic = kTileCacheSetMagic;
	header.version = kTileCacheSetVersion;

	std::vector<std::vector<LayerData>> meshTiles(3);

	for (int m = 0; m < 3; ++m)
	{
		const MeshDef& def = kMeshes[m];
		const float crouch = opt.crouchHeight[m];

		rcConfig cfg;
		memset(&cfg, 0, sizeof(cfg));
		cfg.cs = opt.cellSize;
		cfg.ch = opt.cellHeight;
		cfg.walkableSlopeAngle = def.maxSlope;
		cfg.walkableHeight = (int)ceilf(def.standHeight / cfg.ch);
		cfg.crouchHeight = (int)ceilf(crouch / cfg.ch);
		cfg.walkableClimb = (int)floorf(def.maxStep / cfg.ch);
		cfg.walkableRadius = (int)ceilf(def.radius / cfg.cs);
		cfg.maxSimplificationError = opt.edgeMaxError;
		cfg.tileSize = ts;
		cfg.borderSize = cfg.walkableRadius + 3;
		cfg.width = cfg.tileSize + cfg.borderSize * 2;
		cfg.height = cfg.tileSize + cfg.borderSize * 2;
		rcVcopy(cfg.bmin, bmin);
		rcVcopy(cfg.bmax, bmax);

		NsMeshHeader& mh = header.meshes[m];
		rcVcopy(mh.mesh.orig, bmin);
		mh.mesh.tileWidth = ts * opt.cellSize;
		mh.mesh.tileHeight = ts * opt.cellSize;
		mh.mesh.maxTiles = 1 << tileBits;
		mh.mesh.maxPolys = 1 << polyBits;
		rcVcopy(mh.cache.orig, bmin);
		mh.cache.cs = opt.cellSize;
		mh.cache.ch = opt.cellHeight;
		mh.cache.width = ts;
		mh.cache.height = ts;
		mh.cache.walkableHeight = def.standHeight;
		mh.cache.walkableRadius = def.radius;
		mh.cache.walkableClimb = def.maxStep;
		mh.cache.walkableSlope = def.maxSlope;
		mh.cache.maxSimplificationError = opt.edgeMaxError;
		mh.cache.maxTiles = cacheMaxTiles;
		mh.cache.maxObstacles = 128;
		mh.cache.maxOffMeshConnections = 512;

		for (int y = 0; y < th; ++y)
			for (int x = 0; x < tw; ++x)
				if (rasterizeTileLayers(&ctx, mesh, chunky, m, x, y, cfg, opt, meshTiles[m]) < 0)
				{
					fprintf(stderr, "error: building %s mesh tile %d,%d failed\n", def.name, x, y);
					return 1;
				}

		header.numTiles[m] = (int)meshTiles[m].size();
	}

	FILE* fp = fopen(outPath, "wb");
	if (!fp)
	{
		fprintf(stderr, "error: cannot write %s\n", outPath);
		return 1;
	}
	fwrite(&header, sizeof(header), 1, fp);
	for (int m = 0; m < 3; ++m)
	{
		for (size_t i = 0; i < meshTiles[m].size(); ++i)
		{
			// The tile cache's refs for tiles added in order: salt 1, index i
			NsTileHeader th2 = { (1u << cacheTileBits) | (unsigned int)i, meshTiles[m][i].dataSize };
			fwrite(&th2, sizeof(th2), 1, fp);
			fwrite(meshTiles[m][i].data, meshTiles[m][i].dataSize, 1, fp);
			dtFree(meshTiles[m][i].data);
		}
	}
	header.NumSurfTypes = mesh.getSurfaceTypeCount();
	header.SurfTypesOffset = (int)ftell(fp);
	fwrite(mesh.getSurfaceTypes(), sizeof(int), header.NumSurfTypes, fp);
	const int end = (int)ftell(fp);
	header.OffMeshConsOffset = header.ConvexVolOffset = header.NavHintOffset = end;
	fseek(fp, 0, SEEK_SET);
	fwrite(&header, sizeof(header), 1, fp);
	fclose(fp);

	printf("%s: %d tris, %dx%d tiles, layers regular %d, onos %d, building %d\n", outPath,
	       mesh.getTriCount(), tw, th, header.numTiles[0], header.numTiles[1], header.numTiles[2]);
	return 0;
}

// ---------------------------------------------------------------------------
// dump: one line per tile layer with its header and a hash of the decompressed
// grids, so two files can be compared with diff regardless of tile order.

static uint32_t fnv1a(const unsigned char* p, size_t n, uint32_t h = 2166136261u)
{
	for (size_t i = 0; i < n; ++i)
		h = (h ^ p[i]) * 16777619u;
	return h;
}

static int cmdDump(const char* path)
{
	FILE* fp = fopen(path, "rb");
	if (!fp)
	{
		fprintf(stderr, "error: cannot read %s\n", path);
		return 1;
	}
	NsFileHeader h;
	if (fread(&h, sizeof(h), 1, fp) != 1 || h.magic != kTileCacheSetMagic || h.version != kTileCacheSetVersion)
	{
		fprintf(stderr, "error: %s is not an NS .nav file\n", path);
		return 1;
	}

	printf("tiles %d %d %d surftypes %d offmesh %d convex %d hints %d\n", h.numTiles[0], h.numTiles[1],
	       h.numTiles[2], h.NumSurfTypes, h.NumOffMeshCons, h.NumConvexVols, h.NumNavHints);
	for (int m = 0; m < 3; ++m)
	{
		const NsMeshHeader& mh = h.meshes[m];
		printf("mesh %s orig %g %g %g tile %g maxTiles %d maxPolys %d | cs %g ch %g w %d h %d walk %g/%g/%g/%g err %g max %d %d %d\n",
		       kMeshes[m].name, mh.mesh.orig[0], mh.mesh.orig[1], mh.mesh.orig[2], mh.mesh.tileWidth, mh.mesh.maxTiles,
		       mh.mesh.maxPolys, mh.cache.cs, mh.cache.ch, mh.cache.width, mh.cache.height, mh.cache.walkableHeight,
		       mh.cache.walkableRadius, mh.cache.walkableClimb, mh.cache.walkableSlope, mh.cache.maxSimplificationError,
		       mh.cache.maxTiles, mh.cache.maxObstacles, mh.cache.maxOffMeshConnections);
	}

	FastLZCompressor comp;
	MallocAllocator alloc;
	std::map<int, long> areaTotals[3];
	for (int m = 0; m < 3; ++m)
	{
		for (int i = 0; i < h.numTiles[m]; ++i)
		{
			NsTileHeader th;
			if (fread(&th, sizeof(th), 1, fp) != 1)
			{
				fprintf(stderr, "error: truncated tile header\n");
				return 1;
			}
			std::vector<unsigned char> data(th.dataSize);
			if (fread(data.data(), th.dataSize, 1, fp) != 1)
			{
				fprintf(stderr, "error: truncated tile data\n");
				return 1;
			}
			dtTileCacheLayer* layer = nullptr;
			if (dtStatusFailed(dtDecompressTileCacheLayer(&alloc, &comp, data.data(), th.dataSize, &layer)))
			{
				fprintf(stderr, "error: cannot decompress tile %d of mesh %d\n", i, m);
				return 1;
			}
			const dtTileCacheLayerHeader* lh = layer->header;
			const size_t cells = (size_t)lh->width * lh->height;
			std::map<int, int> areas;
			for (size_t c = 0; c < cells; ++c)
				if (layer->areas[c])
					areas[layer->areas[c]]++;
			for (auto& a : areas)
				areaTotals[m][a.first] += a.second;
			printf("tile %s %d %d %d | %dx%d sub %d-%d %d-%d h %d-%d | heights %08x areas %08x cons %08x | areas",
			       kMeshes[m].name, lh->tx, lh->ty, lh->tlayer, lh->width, lh->height, lh->minx, lh->maxx, lh->miny,
			       lh->maxy, lh->hmin, lh->hmax, fnv1a(layer->heights, cells), fnv1a(layer->areas, cells),
			       fnv1a(layer->cons, cells));
			for (auto& a : areas)
				printf(" %d:%d", a.first, a.second);
			printf("\n");
			dtFreeTileCacheLayer(&alloc, layer);
		}
	}
	for (int m = 0; m < 3; ++m)
	{
		printf("areatotal %s", kMeshes[m].name);
		for (auto& a : areaTotals[m])
			printf(" %d:%ld", a.first, a.second);
		printf("\n");
	}
	fclose(fp);
	return 0;
}

// tile: print one tile layer as a grid, one character per cell: '.' empty,
// '#' walkable, 'c' crouch, '?' other areas; then the heights of walkable
// cells as offsets from hmin in base 36.
static int cmdTile(const char* path, const char* meshName, int tx, int ty, int tl)
{
	FILE* fp = fopen(path, "rb");
	NsFileHeader h;
	if (!fp || fread(&h, sizeof(h), 1, fp) != 1 || h.magic != kTileCacheSetMagic)
	{
		fprintf(stderr, "error: cannot read %s\n", path);
		return 1;
	}
	FastLZCompressor comp;
	MallocAllocator alloc;
	for (int m = 0; m < 3; ++m)
	{
		for (int i = 0; i < h.numTiles[m]; ++i)
		{
			NsTileHeader th;
			if (fread(&th, sizeof(th), 1, fp) != 1)
				return 1;
			std::vector<unsigned char> data(th.dataSize);
			if (fread(data.data(), th.dataSize, 1, fp) != 1)
				return 1;
			if (strcmp(kMeshes[m].name, meshName))
				continue;
			dtTileCacheLayer* layer = nullptr;
			if (dtStatusFailed(dtDecompressTileCacheLayer(&alloc, &comp, data.data(), th.dataSize, &layer)))
				return 1;
			const dtTileCacheLayerHeader* lh = layer->header;
			if (lh->tx == tx && lh->ty == ty && lh->tlayer == tl)
			{
				const char* digits = "0123456789abcdefghijklmnopqrstuvwxyz";
				printf("%s %d,%d layer %d: %dx%d h %d-%d bmin %g %g %g\n", meshName, tx, ty, tl, lh->width,
				       lh->height, lh->hmin, lh->hmax, lh->bmin[0], lh->bmin[1], lh->bmin[2]);
				for (int y = 0; y < lh->height; ++y)
				{
					for (int x = 0; x < lh->width; ++x)
					{
						const unsigned char a = layer->areas[x + y * lh->width];
						putchar(a == 0 ? '.' : a == RC_WALKABLE_AREA ? '#' : a == RC_CROUCH_AREA ? 'c' : '?');
					}
					printf("   ");
					for (int x = 0; x < lh->width; ++x)
					{
						const int c = x + y * lh->width;
						putchar(layer->areas[c] ? digits[layer->heights[c] % 36] : ' ');
					}
					putchar('\n');
				}
				dtFreeTileCacheLayer(&alloc, layer);
				fclose(fp);
				return 0;
			}
			dtFreeTileCacheLayer(&alloc, layer);
		}
	}
	fclose(fp);
	fprintf(stderr, "no such tile\n");
	return 1;
}

static void usage()
{
	fprintf(stderr,
	        "usage: navgen build <map.bsp> <out.nav> [options]\n"
	        "       navgen dump <file.nav>                          per-tile fingerprints\n"
	        "       navgen tile <file.nav> <mesh> <tx> <ty> <layer>  print one tile layer\n"
	        "\n"
	        "Build options take one value per mesh: regular,onos,building (defaults shown)\n"
	        "  --crouch 36,72,100        crouch height (= standing height: no crouch areas)\n"
	        "  --layers-crouch 1,1,1     build layers with the crouch height, not the standing one\n"
	        "  --filter-low-hanging 1,1,1\n"
	        "  --filter-ledges 0,0,1\n"
	        "  --filter-low-height 1,1,1\n");
}

// Parse "a,b,c" into one value per mesh
static bool parseMask(const char* s, bool out[3])
{
	int v[3];
	if (sscanf(s, "%d,%d,%d", &v[0], &v[1], &v[2]) != 3)
		return false;
	for (int i = 0; i < 3; ++i)
		out[i] = v[i] != 0;
	return true;
}

int main(int argc, char** argv)
{
	if (argc >= 3 && !strcmp(argv[1], "dump"))
		return cmdDump(argv[2]);
	if (argc >= 7 && !strcmp(argv[1], "tile"))
		return cmdTile(argv[2], argv[3], atoi(argv[4]), atoi(argv[5]), atoi(argv[6]));
	if (argc >= 4 && !strcmp(argv[1], "build"))
	{
		Options opt;
		for (int i = 4; i < argc; ++i)
		{
			std::string a = argv[i];
			if (a == "--crouch" && i + 1 < argc)
			{
				// regular,onos,building
				if (sscanf(argv[++i], "%f,%f,%f", &opt.crouchHeight[0], &opt.crouchHeight[1], &opt.crouchHeight[2]) != 3)
				{
					usage();
					return 2;
				}
			}
			else if (a == "--layers-crouch" && i + 1 < argc && parseMask(argv[i + 1], opt.layersUseCrouch))
				++i;
			else if (a == "--filter-low-hanging" && i + 1 < argc && parseMask(argv[i + 1], opt.filterLowHanging))
				++i;
			else if (a == "--filter-ledges" && i + 1 < argc && parseMask(argv[i + 1], opt.filterLedges))
				++i;
			else if (a == "--filter-low-height" && i + 1 < argc && parseMask(argv[i + 1], opt.filterLowHeight))
				++i;
			else
			{
				usage();
				return 2;
			}
		}
		return cmdBuild(argv[2], argv[3], opt);
	}
	usage();
	return 2;
}
