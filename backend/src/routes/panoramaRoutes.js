import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

import express from 'express';
import { cachedJson } from '../lib/cache.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');
const panoramaFile = path.join(dataDir, 'panorama-scenes.json');
const hotspotCatalogFile = path.resolve(
  __dirname,
  '../../../assets/data/panorama_hotspots.json',
);
const publicCacheKey = 'panorama-scenes:public:v4';

async function readPanoramaScenes() {
  try {
    const raw = await fs.readFile(panoramaFile, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

async function readPanoramaHotspots() {
  try {
    const raw = await fs.readFile(hotspotCatalogFile, 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed.hotspots) ? parsed.hotspots : [];
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

function attachPanoramaHotspots(scenes, catalog) {
  const hotspotsByScene = new Map();
  for (const spot of catalog) {
    const sceneId = String(spot.sceneId || '');
    if (!sceneId) continue;
    const sceneHotspots = hotspotsByScene.get(sceneId) || [];
    sceneHotspots.push({
      id: String(spot.id || ''),
      key: String(spot.key || ''),
      label: String(spot.label || ''),
      video_asset: String(spot.videoAsset || ''),
      video_url: String(spot.videoUrl || ''),
      yaw: Number(spot.yaw) || 0,
      pitch: Number(spot.pitch) || 0,
      size: Number(spot.size) || 1,
      sort_order: Number(spot.sortOrder) || 0,
    });
    hotspotsByScene.set(sceneId, sceneHotspots);
  }
  return scenes.map((scene) => ({
    ...scene,
    hotspots: hotspotsByScene.get(String(scene.id)) || scene.hotspots || [],
  }));
}

router.get('/', async (_req, res, next) => {
  try {
    const scenes = await cachedJson(publicCacheKey, 60 * 30, async () => {
      const allScenes = await readPanoramaScenes();
      const hotspotCatalog = await readPanoramaHotspots();
      return attachPanoramaHotspots(
        allScenes.filter((scene) => scene.is_active !== false),
        hotspotCatalog,
      );
    });
    res.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=1800');
    res.json(scenes);
  } catch (err) {
    next(err);
  }
});

export default router;

