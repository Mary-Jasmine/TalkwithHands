import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

import express from 'express';
import { cachedJson } from '../lib/cache.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');
const basicWordFile = path.join(dataDir, 'basic-words.json');
const publicCacheKey = 'basic-words:public';

async function readBasicWords() {
  try {
    const raw = await fs.readFile(basicWordFile, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

router.get('/', async (_req, res, next) => {
  try {
    const basicWords = await cachedJson(publicCacheKey, 60 * 30, async () => {
      const allWords = await readBasicWords();
      return allWords.filter((word) => word.is_active !== false);
    });
    res.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=1800');
    res.json(basicWords);
  } catch (err) {
    next(err);
  }
});

export default router;

