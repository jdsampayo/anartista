/**
 * Deterministic PRNG (mulberry32) so mosaics are reproducible per seed.
 */


function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Polygon geometry shared by the plugin core and the tile-generation
 * algorithms: areas, centroids, hygiene (duplicate/collinear removal),
 * point-in-polygon, and the constraint-aware convex chord splitter that
 * several algorithms reuse to enforce area/side limits.
 */


/** Signed polygon area (shoelace). Positive for counter-clockwise rings. */
function signedArea(poly) {
  let s = 0;
  for (let i = 0, n = poly.length; i < n; i++) {
    const [x1, y1] = poly[i];
    const [x2, y2] = poly[(i + 1) % n];
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
}

function polygonArea(poly) {
  return Math.abs(signedArea(poly));
}

/** Area-weighted centroid of a simple polygon. */
function polygonCentroid(poly) {
  const n = poly.length;
  let a = 0;
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < n; i++) {
    const [x1, y1] = poly[i];
    const [x2, y2] = poly[(i + 1) % n];
    const cross = x1 * y2 - x2 * y1;
    a += cross;
    cx += (x1 + x2) * cross;
    cy += (y1 + y2) * cross;
  }
  a /= 2;
  if (Math.abs(a) < 1e-9) {
    // Degenerate polygon: fall back to the vertex average.
    let sx = 0;
    let sy = 0;
    for (const [x, y] of poly) {
      sx += x;
      sy += y;
    }
    return [sx / n, sy / n];
  }
  return [cx / (6 * a), cy / (6 * a)];
}

/** Point-in-convex-polygon test (assumes consistent winding). */
function pointInConvexPolygon(px, py, poly) {
  const n = poly.length;
  let sign = 0;
  for (let i = 0; i < n; i++) {
    const [x1, y1] = poly[i];
    const [x2, y2] = poly[(i + 1) % n];
    const cross = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1);
    if (Math.abs(cross) < 1e-9) continue;
    const s = cross > 0 ? 1 : -1;
    if (sign === 0) sign = s;
    else if (s !== sign) return false;
  }
  return true;
}

/** General point-in-polygon test (even-odd ray cast; handles concave). */
function pointInPolygon(px, py, poly) {
  let inside = false;
  const n = poly.length;
  for (let i = 0, j = n - 1; i < n; j = i++) {
    const [xi, yi] = poly[i];
    const [xj, yj] = poly[j];
    if (
      yi > py !== yj > py &&
      px < ((xj - xi) * (py - yi)) / (yj - yi) + xi
    ) {
      inside = !inside;
    }
  }
  return inside;
}

/**
 * Remove duplicate and collinear vertices so side counts stay honest.
 * This is what turns a "cut through a vertex" into a genuinely smaller
 * polygon rather than one with a zero-length edge.
 */
function cleanPolygon(poly, eps = 1e-6) {
  // 1. Drop near-duplicate consecutive points.
  let pts = [];
  for (const p of poly) {
    const last = pts[pts.length - 1];
    if (!last || Math.abs(last[0] - p[0]) > eps || Math.abs(last[1] - p[1]) > eps) {
      pts.push(p);
    }
  }
  if (pts.length > 1) {
    const first = pts[0];
    const last = pts[pts.length - 1];
    if (Math.abs(first[0] - last[0]) <= eps && Math.abs(first[1] - last[1]) <= eps) {
      pts.pop();
    }
  }
  // 2. Drop collinear vertices.
  const out = [];
  const n = pts.length;
  for (let i = 0; i < n; i++) {
    const a = pts[(i - 1 + n) % n];
    const b = pts[i];
    const c = pts[(i + 1) % n];
    const cross = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    if (Math.abs(cross) > eps) out.push(b);
  }
  return out.length >= 3 ? out : pts;
}

/** Isoperimetric compactness: 1 for a circle, -> 0 for slivers. */
function compactness(poly) {
  let perim = 0;
  for (let k = 0; k < poly.length; k++) {
    const a = poly[k];
    const b = poly[(k + 1) % poly.length];
    perim += Math.hypot(b[0] - a[0], b[1] - a[1]);
  }
  return (4 * Math.PI * polygonArea(poly)) / (perim * perim);
}

/** Linear interpolation between two points. */
function lerpPoint(a, b, t) {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}

/**
 * Split a convex polygon with a straight chord.
 *
 * The chord runs from a point at parameter `ti` along edge `i`
 * (edge i = segment poly[i] -> poly[i+1]) to a point at `tj` along edge `j`.
 * `t` values of 0 or 1 place the endpoint exactly on a vertex, which the
 * cleaner then collapses — this is how vertex-to-edge cuts are expressed.
 *
 * @returns {[poly, poly] | null} two convex polygons, or null if degenerate.
 */
function splitConvexPolygon(poly, i, ti, j, tj) {
  const n = poly.length;
  if (i === j) return null;
  const a = lerpPoint(poly[i], poly[(i + 1) % n], ti);
  const b = lerpPoint(poly[j], poly[(j + 1) % n], tj);

  // Piece A: a -> vertices (i+1 .. j) -> b
  const pieceA = [a];
  for (let k = (i + 1) % n; ; k = (k + 1) % n) {
    pieceA.push(poly[k]);
    if (k === j) break;
  }
  pieceA.push(b);

  // Piece B: b -> vertices (j+1 .. i) -> a
  const pieceB = [b];
  for (let k = (j + 1) % n; ; k = (k + 1) % n) {
    pieceB.push(poly[k]);
    if (k === i) break;
  }
  pieceB.push(a);

  const A = cleanPolygon(pieceA);
  const B = cleanPolygon(pieceB);
  if (A.length < 3 || B.length < 3) return null;
  return [A, B];
}

/**
 * Find a valid straight-chord split of a convex polygon: both pieces must
 * be >= minArea, have <= maxSides sides, and (in the early attempts) be
 * reasonably compact so tiles look like hand-cut tesserae, not shards.
 * The compactness requirement relaxes progressively so a split is found
 * whenever one exists.
 *
 * @returns {[poly, poly] | null}
 */
function trySplitPolygon(poly, minArea, maxSides, rand) {
  const n = poly.length;

  const attempt = (i, ti, j, tj, minCompact) => {
    const pieces = splitConvexPolygon(poly, i, ti, j, tj);
    if (!pieces) return null;
    const [A, B] = pieces;
    if (A.length > maxSides || B.length > maxSides) return null;
    const aA = polygonArea(A);
    const aB = polygonArea(B);
    if (aA < minArea || aB < minArea) return null;
    if (
      minCompact > 0 &&
      (compactness(A) < minCompact || compactness(B) < minCompact)
    ) {
      return null;
    }
    return pieces;
  };

  // Phase 1: random edge-to-edge chords, biased toward long edges and
  // mid-edge cut points.
  const edgeLengths = poly.map((p, i) => {
    const q = poly[(i + 1) % n];
    return Math.hypot(q[0] - p[0], q[1] - p[1]);
  });
  const totalLen = edgeLengths.reduce((s, l) => s + l, 0);
  const pickEdge = () => {
    let r = rand() * totalLen;
    for (let i = 0; i < n; i++) {
      r -= edgeLengths[i];
      if (r <= 0) return i;
    }
    return n - 1;
  };

  // Progressively relax the compactness requirement so subdivision always
  // makes progress even on awkward shapes.
  for (const minCompact of [0.45, 0.3, 0.18]) {
    for (let tries = 0; tries < 30; tries++) {
      const i = pickEdge();
      let j = pickEdge();
      if (j === i) j = (i + 1 + Math.floor(rand() * (n - 1))) % n;
      const ti = 0.25 + rand() * 0.5;
      const tj = 0.25 + rand() * 0.5;
      const pieces = attempt(
        Math.min(i, j),
        i < j ? ti : tj,
        Math.max(i, j),
        i < j ? tj : ti,
        minCompact,
      );
      if (pieces) return pieces;
    }
  }

  // Phase 2: vertex-to-edge cuts (t = 0 puts the endpoint on a vertex).
  // Needed when maxSides is tight, e.g. splitting triangles into triangles.
  for (let tries = 0; tries < 40; tries++) {
    const i = Math.floor(rand() * n);
    let j = Math.floor(rand() * n);
    if (j === i) continue;
    const tj = 0.3 + rand() * 0.4;
    const pieces = attempt(
      Math.min(i, j),
      i < j ? 0 : tj,
      Math.max(i, j),
      i < j ? tj : 0,
      0.12,
    );
    if (pieces) return pieces;
  }

  // Phase 3: exhaustive sweep of edge pairs with a few fixed t values and
  // no compactness requirement — correctness over beauty as a last resort.
  const ts = [0.5, 0.35, 0.65, 0, 0.25, 0.75];
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      for (const ti of ts) {
        for (const tj of ts) {
          const pieces = attempt(i, ti, j, tj, 0);
          if (pieces) return pieces;
        }
      }
    }
  }
  return null;
}

/**
 * Colour handling: median-cut palette extraction and nearest-palette-entry
 * lookup with a perceptually weighted RGB distance.
 */


/**
 * Median-cut colour quantisation.
 *
 * @param {Uint8ClampedArray} data  RGBA pixel data.
 * @param {number} maxColors        Palette size ceiling.
 * @param {number} sampleStride     Read every Nth pixel (performance).
 * @returns {Array<[r,g,b]>}        Up to maxColors dominant colours.
 */
function medianCutPalette(data, maxColors, sampleStride) {
  // Collect samples (skip fully transparent pixels).
  const samples = [];
  for (let p = 0; p < data.length; p += 4 * sampleStride) {
    if (data[p + 3] < 8) continue;
    samples.push([data[p], data[p + 1], data[p + 2]]);
  }
  if (samples.length === 0) return [[0, 0, 0]];

  const boxes = [samples];

  const boxRange = (box) => {
    let min = [255, 255, 255];
    let max = [0, 0, 0];
    for (const c of box) {
      for (let ch = 0; ch < 3; ch++) {
        if (c[ch] < min[ch]) min[ch] = c[ch];
        if (c[ch] > max[ch]) max[ch] = c[ch];
      }
    }
    const ranges = [max[0] - min[0], max[1] - min[1], max[2] - min[2]];
    const channel = ranges.indexOf(Math.max(...ranges));
    return { channel, spread: ranges[channel] };
  };

  while (boxes.length < maxColors) {
    // Pick the box with the widest colour spread that can still be split.
    let bestIdx = -1;
    let bestSpread = 0;
    let bestChannel = 0;
    for (let b = 0; b < boxes.length; b++) {
      if (boxes[b].length < 2) continue;
      const { channel, spread } = boxRange(boxes[b]);
      // Weight spread by population so large uniform areas keep priority.
      const score = spread * Math.sqrt(boxes[b].length);
      if (spread > 0 && score > bestSpread) {
        bestSpread = score;
        bestIdx = b;
        bestChannel = channel;
      }
    }
    if (bestIdx === -1) break; // No box can be split further.

    const box = boxes[bestIdx];
    box.sort((c1, c2) => c1[bestChannel] - c2[bestChannel]);
    const mid = box.length >> 1;
    boxes.splice(bestIdx, 1, box.slice(0, mid), box.slice(mid));
  }

  // Average each box into one palette entry, dropping exact duplicates.
  const palette = [];
  const seen = new Set();
  for (const box of boxes) {
    let r = 0;
    let g = 0;
    let b = 0;
    for (const c of box) {
      r += c[0];
      g += c[1];
      b += c[2];
    }
    const entry = [
      Math.round(r / box.length),
      Math.round(g / box.length),
      Math.round(b / box.length),
    ];
    const key = entry.join(',');
    if (!seen.has(key)) {
      seen.add(key);
      palette.push(entry);
    }
  }
  return palette;
}

/** Index of the palette colour nearest to (r,g,b) in RGB space. */
function nearestPaletteIndex(palette, r, g, b) {
  let best = 0;
  let bestDist = Infinity;
  for (let i = 0; i < palette.length; i++) {
    const p = palette[i];
    const dr = p[0] - r;
    const dg = p[1] - g;
    const db = p[2] - b;
    // Perceptual-ish weighting (green dominates luminance).
    const d = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

/**
 * "recursive-chord" tile generation — see the doc comment on the
 * exported function. Part of the built-in algorithm set; the generator
 * contract is documented in ./index.js.
 */


/**
 * "recursive-chord" — top-down stochastic splitting.
 *
 * Starting from the image rectangle, any tile above maxArea is cut by a
 * straight chord (see trySplitPolygon). Fast and shard-like; note that
 * early cuts necessarily span the whole image, so long straight fractures
 * are a characteristic of this style.
 */
async function recursiveChordTiles(ctx) {
  const { width, height, minArea, maxArea, maxSides, rand, maybeYield } = ctx;
  const done = [];
  const queue = [
    [
      [0, 0],
      [width, 0],
      [width, height],
      [0, height],
    ],
  ];

  while (queue.length > 0) {
    const poly = queue.pop();
    if (polygonArea(poly) <= maxArea) {
      done.push(poly);
    } else {
      const pieces = trySplitPolygon(poly, minArea, maxSides, rand);
      if (pieces) {
        queue.push(pieces[0], pieces[1]);
      } else {
        // Constraints could not be met (pathological shape) — keep as-is
        // rather than looping forever. Extremely rare in practice.
        done.push(poly);
      }
    }
    await maybeYield();
  }
  return done;
}

/**
 * "voronoi" tile generation — see the doc comment on the exported
 * function. Part of the built-in algorithm set; the generator contract
 * is documented in ./index.js.
 */


/**
 * Clip a convex polygon to the half-plane of points closer to seed s than
 * to seed o (the perpendicular-bisector half-plane). Sutherland–Hodgman.
 */
function clipToBisector(poly, sx, sy, ox, oy) {
  const mx = (sx + ox) / 2;
  const my = (sy + oy) / 2;
  const dx = ox - sx;
  const dy = oy - sy;
  // f(p) <= 0  <=>  p is on the seed's side of the bisector.
  const out = [];
  const n = poly.length;
  for (let i = 0; i < n; i++) {
    const a = poly[i];
    const b = poly[(i + 1) % n];
    const fa = (a[0] - mx) * dx + (a[1] - my) * dy;
    const fb = (b[0] - mx) * dx + (b[1] - my) * dy;
    if (fa <= 0) {
      out.push(a);
      if (fb > 0) {
        const t = fa / (fa - fb);
        out.push(lerpPoint(a, b, t));
      }
    } else if (fb <= 0) {
      const t = fa / (fa - fb);
      out.push(lerpPoint(a, b, t));
    }
  }
  return out;
}

/**
 * Bounded Voronoi diagram of `seeds` clipped to [0,w]x[0,h].
 *
 * Each cell is built by clipping the image rectangle against the bisector
 * of every *nearby* seed; a uniform grid provides candidates in increasing
 * distance and clipping stops once the next candidate is farther than
 * twice the cell's current max seed-to-vertex distance (at that point no
 * remaining bisector can touch the cell). O(N x neighbours) in practice.
 *
 * @returns {Array<polygon|null>} cell per seed (null if it vanished).
 */
function boundedVoronoi(seeds, w, h, bucketSize) {
  const gw = Math.max(1, Math.ceil(w / bucketSize));
  const gh = Math.max(1, Math.ceil(h / bucketSize));
  const grid = new Array(gw * gh);
  for (let k = 0; k < seeds.length; k++) {
    const [x, y] = seeds[k];
    const gx = Math.min(gw - 1, Math.max(0, Math.floor(x / bucketSize)));
    const gy = Math.min(gh - 1, Math.max(0, Math.floor(y / bucketSize)));
    const idx = gy * gw + gx;
    (grid[idx] || (grid[idx] = [])).push(k);
  }

  const cells = new Array(seeds.length);

  for (let k = 0; k < seeds.length; k++) {
    const [sx, sy] = seeds[k];
    let poly = [
      [0, 0],
      [w, 0],
      [w, h],
      [0, h],
    ];

    const maxVertexDist = () => {
      let m = 0;
      for (const [x, y] of poly) {
        const d = Math.hypot(x - sx, y - sy);
        if (d > m) m = d;
      }
      return m;
    };

    const gx0 = Math.min(gw - 1, Math.max(0, Math.floor(sx / bucketSize)));
    const gy0 = Math.min(gh - 1, Math.max(0, Math.floor(sy / bucketSize)));
    const maxRing = Math.max(gw, gh);
    const seen = new Set([k]);
    let candidates = [];
    let done = false;

    // Expand ring by ring; each ring adds candidates, which are processed
    // in order of true distance to the seed.
    for (let ring = 0; ring <= maxRing && !done; ring++) {
      const ringCands = [];
      for (let gy = gy0 - ring; gy <= gy0 + ring; gy++) {
        if (gy < 0 || gy >= gh) continue;
        for (let gx = gx0 - ring; gx <= gx0 + ring; gx++) {
          if (gx < 0 || gx >= gw) continue;
          if (Math.max(Math.abs(gx - gx0), Math.abs(gy - gy0)) !== ring) continue;
          const bucket = grid[gy * gw + gx];
          if (!bucket) continue;
          for (const idx of bucket) {
            if (seen.has(idx)) continue;
            seen.add(idx);
            const [ox, oy] = seeds[idx];
            ringCands.push([Math.hypot(ox - sx, oy - sy), ox, oy]);
          }
        }
      }
      // Merge and re-sort: leftovers from earlier rings can be *farther*
      // than fresh candidates from this ring (a ring's buckets hold seeds
      // across a wide distance range), and the early-exit test below is
      // only sound if candidates[0] is truly the nearest unprocessed seed.
      candidates = candidates.concat(ringCands);
      candidates.sort((p, q) => p[0] - q[0]);

      // Clip against every candidate that can still affect the cell.
      while (candidates.length > 0) {
        const limit = 2 * maxVertexDist();
        if (candidates[0][0] > limit) {
          // Nearest unprocessed candidate is already too far. If all seeds
          // beyond the explored rings are also guaranteed too far, finish.
          const ringMinDist = ring * bucketSize; // lower bound for next ring
          if (ringMinDist > limit) done = true;
          break;
        }
        const [, ox, oy] = candidates.shift();
        poly = clipToBisector(poly, sx, sy, ox, oy);
        if (poly.length < 3) break;
      }
      if (poly.length < 3) break;
      if (candidates.length === 0 && ring * bucketSize > 2 * maxVertexDist()) {
        done = true;
      }
    }

    poly = poly.length >= 3 ? cleanPolygon(poly) : poly;
    cells[k] = poly.length >= 3 ? poly : null;
  }
  return cells;
}

/**
 * "voronoi" — organic cellular tessellation (default).
 *
 * 1. Scatter seeds on a jittered grid (even coverage, no visible axes).
 * 2. Refine: partial Lloyd relaxation evens the cells out while
 *    undersized cells lose their seed and oversized cells gain one.
 * 3. Guarantee minArea / maxSides: repeatedly drop seeds whose cells
 *    can't satisfy the constraints (each drop enlarges the neighbours,
 *    so this terminates).
 * 4. Guarantee maxArea: chord-split any still-oversized cell — those
 *    cuts are local to one cell, so no long fractures appear.
 */
async function voronoiTiles(ctx) {
  return generateVoronoiCells(ctx);
}

/**
 * The reusable core of the voronoi algorithm. `hooks` lets content-aware
 * algorithms (e.g. "stained-glass") customise it without duplicating the
 * refinement/guarantee machinery:
 *   hooks.targetArea  — desired average cell area (default: mid-range,
 *                       biased to keep headroom above minArea)
 *   hooks.relaxation  — Lloyd iterations (default: options.voronoiRelaxation)
 *   hooks.centroidOf  — (cell) => [x, y] used as the Lloyd attractor
 *                       (default: the geometric centroid; a gradient-
 *                       weighted centroid makes bisectors follow contours)
 */
async function generateVoronoiCells(ctx, hooks = {}) {
  const { width, height, minArea, maxArea, maxSides, rand, options, maybeYield } = ctx;

  // Target the middle of the allowed range, but keep enough headroom above
  // minArea that refinement rarely produces unsplittable small cells.
  const target =
    hooks.targetArea ||
    Math.min(maxArea * 0.75, Math.max((minArea + maxArea) / 2, 3 * minArea));
  const bucketSize = Math.sqrt(target);
  const relaxation =
    hooks.relaxation != null ? hooks.relaxation : options.voronoiRelaxation;
  const centroidOf = hooks.centroidOf || polygonCentroid;

  // 1. Jittered grid of seeds.
  let seeds = [];
  const cols = Math.max(1, Math.round(width / bucketSize));
  const rows = Math.max(1, Math.round(height / bucketSize));
  const cw = width / cols;
  const ch = height / rows;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      seeds.push([
        (c + 0.12 + 0.76 * rand()) * cw,
        (r + 0.12 + 0.76 * rand()) * ch,
      ]);
    }
  }

  // 2. Refinement rounds: partial Lloyd + seed add/remove for area control.
  const rounds = Math.max(relaxation, 2) + 2;
  for (let round = 0; round < rounds; round++) {
    const cells = boundedVoronoi(seeds, width, height, bucketSize);
    const next = [];
    let changed = false;
    for (let k = 0; k < seeds.length; k++) {
      const cell = cells[k];
      if (!cell) {
        changed = true;
        continue; // seed's cell vanished (duplicate point) — drop it
      }
      const area = polygonArea(cell);
      if (area < minArea * 1.1 && seeds.length > 1) {
        changed = true;
        continue; // drop seed: neighbours absorb this cell
      }
      const [cx, cy] = centroidOf(cell);
      if (round < relaxation) {
        // Partial Lloyd move (0.75 toward the centroid): evens areas out
        // without collapsing into a too-regular honeycomb.
        const [sx, sy] = seeds[k];
        next.push([sx + (cx - sx) * 0.75, sy + (cy - sy) * 0.75]);
      } else {
        next.push(seeds[k]);
      }
      if (area > maxArea * 1.35) {
        // Add a seed off-centre inside the oversized cell.
        let fx = cx;
        let fy = cy;
        let fd = 0;
        for (const [x, y] of cell) {
          const d = Math.hypot(x - cx, y - cy);
          if (d > fd) {
            fd = d;
            fx = x;
            fy = y;
          }
        }
        next.push([cx + (fx - cx) * 0.55, cy + (fy - cy) * 0.55]);
        changed = true;
      }
    }
    seeds = next.length > 0 ? next : seeds;
    await maybeYield();
    if (!changed && round >= relaxation) break;
  }

  // 3. Hard guarantees for minArea and maxSides: drop offending seeds and
  // recompute. Every drop strictly reduces the seed count, so this loop
  // terminates (worst case: one seed = one rectangular cell).
  let cells;
  for (let guard = 0; guard < 60; guard++) {
    cells = boundedVoronoi(seeds, width, height, bucketSize);
    const keep = [];
    for (let k = 0; k < seeds.length; k++) {
      const cell = cells[k];
      if (!cell) continue;
      const area = polygonArea(cell);
      const unsplittableSides = cell.length > maxSides && area < 2 * minArea;
      if ((area < minArea || unsplittableSides) && seeds.length > 1) continue;
      keep.push(seeds[k]);
    }
    if (keep.length === seeds.length) break;
    seeds = keep.length > 0 ? keep : seeds.slice(0, 1);
    await maybeYield();
  }
  cells = boundedVoronoi(seeds, width, height, bucketSize).filter(Boolean);

  // 4. Enforce maxArea / maxSides with local chord splits.
  const done = [];
  const queue = cells;
  while (queue.length > 0) {
    const poly = queue.pop();
    if (polygonArea(poly) > maxArea || poly.length > maxSides) {
      const pieces = trySplitPolygon(poly, minArea, maxSides, rand);
      if (pieces) {
        queue.push(pieces[0], pieces[1]);
      } else {
        done.push(poly); // pathological; extremely rare
      }
    } else {
      done.push(poly);
    }
    await maybeYield();
  }
  return done;
}

/**
 * "tangram" tile generation — see the doc comment below. Part of the
 * built-in algorithm set; the generator contract is documented in
 * ./index.js.
 */


/**
 * "tangram" — Chinese-puzzle tiling from the 7 classic pieces.
 *
 * The canvas is divided into a grid of pattern cells; each cell holds the
 * classic tangram dissection (2 large triangles, 1 medium triangle,
 * 2 small triangles, 1 square, 1 parallelogram — verified to tile the
 * unit square exactly). Per-cell rotation/mirroring and optional
 * half-cell row offsets (`tangramVariation`) break up visible repetition.
 *
 * Constraint strategy — every tangram piece is a power-of-two multiple of
 * the small triangle ("unit"), and every piece halves into two smaller
 * 45/90 shapes (triangles: median to the hypotenuse; quads: the short
 * diagonal, which for the parallelogram yields two right isosceles
 * triangles). So the cell is sized to make the unit piece >= minArea,
 * and any piece over maxArea (or over maxSides) is simply halved: the
 * halves are > maxArea/2 >= minArea (guaranteed by the validated
 * `maxTileArea >= 2 x minTileArea`), which proves all constraints.
 */

/** The classic 7-piece dissection of the unit square (areas sum to 1). */
const TANGRAM_UNIT = [
  [[0, 0], [0, 1], [0.5, 0.5]],                       // large triangle (1/4)
  [[0, 1], [1, 1], [0.5, 0.5]],                       // large triangle (1/4)
  [[0.5, 0], [1, 0], [1, 0.5]],                       // medium triangle (1/8)
  [[0, 0], [0.5, 0], [0.25, 0.25]],                   // small triangle (1/16)
  [[0.25, 0.25], [0.5, 0], [0.75, 0.25], [0.5, 0.5]], // square (1/8)
  [[0.5, 0.5], [0.75, 0.75], [0.75, 0.25]],           // small triangle (1/16)
  [[0.75, 0.25], [1, 0.5], [1, 1], [0.75, 0.75]],     // parallelogram (1/8)
];

/** Rotate (k x 90 degrees) and optionally mirror a unit-square point. */
function tangramTransform(pt, rot, mirror) {
  let [x, y] = pt;
  if (mirror) x = 1 - x;
  for (let k = 0; k < rot; k++) {
    const t = x;
    x = y;
    y = 1 - t;
  }
  return [x, y];
}

/**
 * Halve a 45/90 unit-space piece into two 45/90 pieces of equal area:
 * triangles split by the median to the hypotenuse (longest side), quads
 * along their shorter diagonal. Works on the tangram lattice, where these
 * cuts always land on exact midpoints.
 */
function halveUnitPiece(poly) {
  if (poly.length === 3) {
    let hi = 0;
    let hlen = -1;
    for (let i = 0; i < 3; i++) {
      const a = poly[i];
      const b = poly[(i + 1) % 3];
      const l = (b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2;
      if (l > hlen) {
        hlen = l;
        hi = i;
      }
    }
    const a = poly[hi];
    const b = poly[(hi + 1) % 3];
    const apex = poly[(hi + 2) % 3];
    const m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
    return [
      [apex, a, m],
      [apex, m, b],
    ];
  }
  // Quad: cut along the shorter diagonal (for the tangram square and
  // parallelogram this always yields two right isosceles triangles).
  const d02 = (poly[0][0] - poly[2][0]) ** 2 + (poly[0][1] - poly[2][1]) ** 2;
  const d13 = (poly[1][0] - poly[3][0]) ** 2 + (poly[1][1] - poly[3][1]) ** 2;
  if (d02 <= d13) {
    return [
      [poly[0], poly[1], poly[2]],
      [poly[0], poly[2], poly[3]],
    ];
  }
  return [
    [poly[1], poly[2], poly[3]],
    [poly[1], poly[3], poly[0]],
  ];
}

async function tangramTiles(ctx) {
  const { width, height, minArea, maxArea, maxSides, rand, options, maybeYield } = ctx;
  const variation = options.tangramVariation;

  // Size pattern cells so the smallest piece (cellArea/16) is >= minArea,
  // preferring cells big enough that the large triangles (cellArea/4) fit
  // under maxArea without halving (possible whenever maxArea >= ~4 minArea).
  const u0 = Math.max(minArea * 1.0001, (maxArea / 4) * 0.95);
  const S0 = Math.sqrt(16 * u0);
  let ncols = Math.max(1, Math.round(width / S0));
  let nrows = Math.max(1, Math.round(height / S0));
  while (
    ((width / ncols) * (height / nrows)) / 16 < minArea &&
    (ncols > 1 || nrows > 1)
  ) {
    if (ncols >= nrows && ncols > 1) ncols--;
    else nrows--;
  }
  const cw = width / ncols;
  const ch = height / nrows;
  const cellArea = cw * ch;
  // Rounding can only leave the unit below minArea in the degenerate 1x1
  // case; there, quartering the cell by its diagonals is always valid
  // (cellArea/4 = imageArea/4 >= 2 x minTileArea after small-image scaling).
  const unitOk = cellArea / 16 >= minArea;
  const offsetRows = variation >= 3 && ncols >= 2 && unitOk;

  const tiles = [];

  // Enforce constraints in unit space (where the 45/90 lattice is exact),
  // then scale into the cell at (x0, y0).
  const emit = (normPoly, x0, y0) => {
    const queue = [normPoly];
    while (queue.length > 0) {
      const p = queue.pop();
      if (p.length > maxSides || polygonArea(p) * cellArea > maxArea) {
        const [A, B] = halveUnitPiece(p);
        queue.push(A, B);
      } else {
        tiles.push(p.map(([ux, uy]) => [x0 + ux * cw, y0 + uy * ch]));
      }
    }
  };

  for (let r = 0; r < nrows; r++) {
    const shifted = offsetRows && r % 2 === 1;
    const y0 = r * ch;

    if (shifted) {
      // Offset rows leave a half-cell at each end; fill each with two
      // stacked squares (area cellArea/4 each — well above minArea),
      // randomly split diagonally for variety.
      for (const x0 of [0, width - cw / 2]) {
        for (const sq of [
          [[0, 0], [0.5, 0], [0.5, 0.5], [0, 0.5]],
          [[0, 0.5], [0.5, 0.5], [0.5, 1], [0, 1]],
        ]) {
          if (rand() < 0.5) {
            for (const half of halveUnitPiece(sq)) emit(half, x0, y0);
          } else {
            emit(sq, x0, y0);
          }
        }
      }
    }

    const cells = shifted ? ncols - 1 : ncols;
    for (let c = 0; c < cells; c++) {
      const x0 = (shifted ? c + 0.5 : c) * cw;
      const rot = variation >= 1 ? Math.floor(rand() * 4) : 0;
      const mir = variation >= 2 ? rand() < 0.5 : false;
      if (unitOk) {
        for (const piece of TANGRAM_UNIT) {
          emit(piece.map((pt) => tangramTransform(pt, rot, mir)), x0, y0);
        }
      } else {
        // Degenerate fallback: quarter the cell with both diagonals.
        const ce = [0.5, 0.5];
        emit([[0, 0], [1, 0], ce], x0, y0);
        emit([[1, 0], [1, 1], ce], x0, y0);
        emit([[1, 1], [0, 1], ce], x0, y0);
        emit([[0, 1], [0, 0], ce], x0, y0);
      }
      await maybeYield();
    }
  }
  return tiles;
}

/**
 * "grid" tile generation — see the doc comment on the exported function.
 * Part of the built-in algorithm set; the generator contract is
 * documented in ./index.js.
 */


/**
 * "grid" — uniform ceramic-tile grid (swimming pool / bathroom-wall look).
 *
 * The canvas is covered by a perfectly regular grid of rectangles whose
 * size is `width/ncols x height/nrows` — integer counts are searched so
 * that every emitted piece's area lands inside [minArea, maxArea], the
 * canvas is covered exactly (no cropped or partial edge tiles), and the
 * tile aspect stays as close as possible to the shape's ideal (1:1 for
 * squares, 2:1 for bricks and stacked rectangles).
 *
 * options.gridShape:
 *   - 'square'            checkerboard of (near-)squares
 *   - 'brick'             2:1 tiles in running bond ("subway tile"):
 *                         alternate rows offset by half a tile, ending in
 *                         half tiles. If the area window is too tight for
 *                         half tiles (they need full >= 2 x minArea), the
 *                         layout degrades gracefully: 1.5-width end tiles,
 *                         then plain stacked rows.
 *   - 'stacked-rectangle' 2:1 tiles aligned without offset (industrial)
 *
 * maxSides is honoured rather than ignored: with maxSides = 3 every
 * rectangle is split along a diagonal (alternating direction for a woven
 * look). Since a diagonal halves every piece, both area bounds simply
 * scale by 1/2 in the tile-size search and all constraints still hold.
 */
async function gridTiles(ctx) {
  const { width, height, minArea, maxArea, maxSides, options, maybeYield } = ctx;
  const shape = options.gridShape;
  const aspect = shape === 'square' ? 1 : 2; // tile width : height
  const triangles = maxSides < 4;
  const factorScale = triangles ? 0.5 : 1; // diagonal split halves everything

  // Layout variants in preference order. `edge` describes how offset rows
  // terminate; min/maxFactor are the smallest/largest emitted piece sizes
  // relative to a full tile, from which bounds on the full-tile area are
  // derived so that EVERY piece respects [minArea, maxArea].
  const variants =
    shape === 'brick'
      ? [
          { edge: 'half', minFactor: 0.5, maxFactor: 1 },
          { edge: 'wide', minFactor: 1, maxFactor: 1.5 },
          { edge: null, minFactor: 1, maxFactor: 1 },
        ]
      : [{ edge: null, minFactor: 1, maxFactor: 1 }];

  let chosen = null;
  for (const variant of variants) {
    const A0 = minArea / (variant.minFactor * factorScale);
    const A1 = maxArea / (variant.maxFactor * factorScale);
    if (A1 < A0 - 1e-9) continue;
    const target = Math.sqrt(A0 * A1);
    const imgArea = width * height;
    const maxRows = Math.max(1, Math.floor(imgArea / A0));

    let best = null;
    for (let nrows = 1; nrows <= maxRows; nrows++) {
      const th = height / nrows;
      // Integer column counts for which the full-tile area is in [A0, A1].
      const cMin = Math.max(1, Math.ceil(imgArea / (A1 * nrows) - 1e-9));
      let cMax = Math.floor(imgArea / (A0 * nrows) + 1e-9);
      if (cMin > cMax) continue;
      let c = Math.round(width / (aspect * th)); // ideal-aspect column count
      c = Math.min(cMax, Math.max(cMin, c));
      if (variant.edge === 'wide') {
        // Wide end tiles need at least 3 columns (1.5 + n + 1.5).
        c = Math.max(c, 3);
        if (c > cMax) continue;
      }
      const tw = width / c;
      const area = tw * th;
      const score =
        2 * Math.abs(Math.log(tw / th / aspect)) +
        0.5 * Math.abs(Math.log(area / target));
      if (!best || score < best.score) best = { ncols: c, nrows, score };
    }
    if (best) {
      chosen = { edge: variant.edge, ncols: best.ncols, nrows: best.nrows };
      break;
    }
  }
  if (!chosen) {
    // Unreachable for valid options (the stacked variant always admits an
    // integer solution), but fail loudly rather than render nonsense.
    throw new Error(
      'MosaicPlugin: could not fit a grid layout within the tile-area bounds.',
    );
  }

  const { ncols, nrows, edge } = chosen;
  const tw = width / ncols;
  const th = height / nrows;

  const tiles = [];
  const emitRect = (x0, y0, x1, y1, parity) => {
    if (triangles) {
      // Alternating diagonal direction gives a woven harlequin pattern.
      if (parity === 0) {
        tiles.push(
          [[x0, y0], [x1, y0], [x1, y1]],
          [[x0, y0], [x1, y1], [x0, y1]],
        );
      } else {
        tiles.push(
          [[x0, y0], [x1, y0], [x0, y1]],
          [[x1, y0], [x1, y1], [x0, y1]],
        );
      }
    } else {
      tiles.push([[x0, y0], [x1, y0], [x1, y1], [x0, y1]]);
    }
  };

  for (let r = 0; r < nrows; r++) {
    const y0 = r * th;
    const y1 = (r + 1) * th;
    const offset = edge != null && r % 2 === 1;

    // Column boundaries for this row (shared exactly between neighbours,
    // and vertically with the rows above/below via identical expressions).
    let bounds;
    if (!offset) {
      bounds = [];
      for (let c = 0; c <= ncols; c++) bounds.push(c * tw);
    } else if (edge === 'half') {
      bounds = [0];
      for (let c = 0; c < ncols; c++) bounds.push(tw / 2 + c * tw);
      bounds.push(width);
    } else {
      // 'wide': 1.5-tile ends (requires ncols >= 3, enforced in search).
      bounds = [0];
      for (let c = 0; c < ncols - 2; c++) bounds.push(1.5 * tw + c * tw);
      bounds.push(width);
    }

    for (let i = 0; i < bounds.length - 1; i++) {
      emitRect(bounds[i], y0, bounds[i + 1], y1, (r + i) % 2);
    }
    await maybeYield();
  }
  return tiles;
}

/**
 * "trencadis" tile generation — Gaudí-style broken-ceramic mosaic.
 * Part of the built-in algorithm set; the generator contract is
 * documented in ./index.js (this algorithm uses the rich return form:
 * { polygon, curves }).
 *
 * Approach: a constrained Voronoi tessellation (reusing the voronoi
 * algorithm verbatim) provides the local, organic fracture layout; every
 * interior edge is then replaced by a cubic Bézier curve that BOTH
 * neighbouring pieces share exactly. Independent perpendicular offsets at
 * the 1/3 and 2/3 control points produce both bulges and S-curves, so
 * pieces become concave and edges wander like real pottery fractures.
 *
 * Why this is safe:
 *   - Coverage stays mathematically exact: a shared curve transfers area
 *     from one neighbour to the other, zero-sum, no gaps or overlaps.
 *   - Area bounds stay guaranteed: with all control displacements
 *     parallel to the edge normal, the area a curve transfers is EXACTLY
 *     linear in the offset scale (the quadratic cross-terms of the
 *     shoelace formula cancel), so a greedy pass can clamp each curve's
 *     scale to keep both neighbours inside [minArea, maxArea].
 *   - Only edges shared by exactly two pieces are curved. Canvas-border
 *     edges and T-junction remnants (from the Voronoi enforcement step)
 *     stay straight on both sides, so they always coincide.
 *   - The cubic with controls at exactly 1/3 and 2/3 along the chord has
 *     linear parametrisation along the chord, so the sampled polygon used
 *     for area/colour accounting lies exactly on the true Bézier that the
 *     painter strokes.
 *
 * maxSides limits the number of curve segments per piece (it is inherited
 * from the underlying Voronoi cell's side count). options.curvature in
 * [0, 1] scales how far edges may bow; 0 degenerates to plain Voronoi.
 */


/** Cubic Bernstein basis for the two inner control points. */
const B1 = (t) => 3 * t * (1 - t) * (1 - t);
const B2 = (t) => 3 * t * t * (1 - t);

/**
 * Sample the cubic Bézier with controls a + (b-a)/3 + h1*n and
 * a + 2(b-a)/3 + h2*n. Because those controls sit at exactly 1/3 and 2/3
 * of the chord, the curve's chordwise coordinate is linear in t, so
 * sample i sits at chord parameter i/S displaced by (h1*B1 + h2*B2)
 * along the unit normal n — i.e. exactly on the true Bézier.
 */
function curveSamples(a, b, n, h1, h2, S) {
  const pts = [a];
  for (let i = 1; i < S; i++) {
    const t = i / S;
    const d = h1 * B1(t) + h2 * B2(t);
    pts.push([
      a[0] + (b[0] - a[0]) * t + n[0] * d,
      a[1] + (b[1] - a[1]) * t + n[1] * d,
    ]);
  }
  pts.push(b);
  return pts;
}

/**
 * Change to a polygon's signed shoelace sum when its straight edge
 * pts[0] -> pts[last] is replaced by the polyline pts. Depends only on
 * the polyline itself, so per-edge deltas can be book-kept independently.
 */
function edgeDelta(pts) {
  let s = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    s += pts[i][0] * pts[i + 1][1] - pts[i + 1][0] * pts[i][1];
  }
  const a = pts[0];
  const b = pts[pts.length - 1];
  s -= a[0] * b[1] - b[0] * a[1];
  return s / 2;
}

async function trencadisTiles(ctx) {
  const { minArea, maxArea, rand, options, maybeYield } = ctx;
  const curvature = options.curvature;

  // 1. Base layout: the constrained Voronoi tessellation (all its area,
  // side-count and locality guarantees carry over).
  const cells = await voronoiTiles(ctx);

  // 2. Canonicalise vertices so both sides of a shared edge reference the
  // SAME point objects (independent per-seed clipping leaves ~1e-9
  // mismatches that would otherwise break edge matching).
  const canon = new Map(); // quantised key -> canonical point
  const vertexId = new Map(); // canonical point -> integer id
  const snap = (p) => {
    const k = `${Math.round(p[0] * 1e4)}_${Math.round(p[1] * 1e4)}`;
    let c = canon.get(k);
    if (!c) {
      c = p;
      canon.set(k, c);
      vertexId.set(c, vertexId.size);
    }
    return c;
  };
  // Normalise winding (positive signed area) so per-edge delta signs are
  // uniform across all cells.
  const polys = cells.map((cell) => {
    const p = cell.map(snap);
    return signedArea(p) >= 0 ? p : p.reverse();
  });

  // 3. Edge registry: canonical key -> the (up to two) cells that use it.
  const registry = new Map();
  for (let ci = 0; ci < polys.length; ci++) {
    const poly = polys[ci];
    for (let ei = 0; ei < poly.length; ei++) {
      const a = poly[ei];
      const b = poly[(ei + 1) % poly.length];
      const ia = vertexId.get(a);
      const ib = vertexId.get(b);
      if (ia === ib) continue;
      const key = ia < ib ? `${ia}_${ib}` : `${ib}_${ia}`;
      let occ = registry.get(key);
      if (!occ) {
        occ = [];
        registry.set(key, occ);
      }
      occ.push({ cell: ci, edge: ei, forward: ia < ib });
    }
  }

  // 4. Assign a shared curve to every interior 1:1 edge, greedily scaled
  // so both neighbours stay inside [minArea, maxArea]. All polygons are
  // positively wound, so signed areas equal real areas here.
  const areas = polys.map((p) => signedArea(p));
  const curveByKey = new Map(); // key -> { pts (canonical a->b), c1, c2 }

  for (const [key, occ] of registry) {
    await maybeYield();
    if (curvature <= 0) break;
    if (occ.length !== 2 || occ[0].cell === occ[1].cell) continue; // border / T-junction / degenerate

    const fwd = occ[0].forward ? occ[0] : occ[1];
    const rev = occ[0].forward ? occ[1] : occ[0];
    if (fwd.forward === rev.forward) continue; // inconsistent winding — keep straight

    const pf = polys[fwd.cell];
    const a = pf[fwd.edge];
    const b = pf[(fwd.edge + 1) % pf.length];
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (len < 6) continue; // too short to curve gracefully

    const n = [-(b[1] - a[1]) / len, (b[0] - a[0]) / len];
    // Cap keeps curves from crossing neighbouring curves near vertices.
    const cap = 0.18 * len * curvature;
    let h1 = (0.35 + 0.65 * rand()) * cap * (rand() < 0.5 ? -1 : 1);
    let h2 = (0.35 + 0.65 * rand()) * cap * (rand() < 0.5 ? -1 : 1);
    const S = Math.max(6, Math.min(24, Math.round(len / 5)));

    let pts = curveSamples(a, b, n, h1, h2, S);
    let D = edgeDelta(pts); // area the forward cell gains (reverse cell loses)

    // Headroom for a transfer of +D from `rev` to `fwd`:
    const headroom = (d) =>
      d >= 0
        ? Math.min(maxArea - areas[fwd.cell], areas[rev.cell] - minArea)
        : Math.min(maxArea - areas[rev.cell], areas[fwd.cell] - minArea);

    if (Math.abs(D) > 1e-9) {
      let room = headroom(D);
      if (room < Math.abs(D)) {
        // Try the mirrored curve (transfers area the other way).
        const flipped = headroom(-D);
        if (flipped > room) {
          h1 = -h1;
          h2 = -h2;
          room = flipped;
        }
      }
      // Displacements are all parallel to n, so the transfer scales EXACTLY
      // linearly with the offsets — clamp the scale to the available
      // headroom (|D| is sign-invariant, so it's valid for either mirror).
      const s = Math.max(0, Math.min(1, room / Math.abs(D)));
      if (s <= 0.02) continue; // not worth a visually flat curve
      h1 *= s;
      h2 *= s;
      // ALWAYS rebuild from the final offsets: the mirror and the scale both
      // change the geometry, and bookkeeping must use the same points that
      // get stored (a stale `pts` here once inverted a transfer's sign and
      // pushed a tile below minArea — see the regression test).
      pts = curveSamples(a, b, n, h1, h2, S);
      D = edgeDelta(pts);
      areas[fwd.cell] += D;
      areas[rev.cell] -= D;
    }

    const third = [(b[0] - a[0]) / 3, (b[1] - a[1]) / 3];
    curveByKey.set(key, {
      pts,
      c1: [a[0] + third[0] + n[0] * h1, a[1] + third[1] + n[1] * h1],
      c2: [a[0] + 2 * third[0] + n[0] * h2, a[1] + 2 * third[1] + n[1] * h2],
    });
  }

  // 5. Assemble tiles: the sampled polygon (for area/colour accounting)
  // plus the exact curve segments (for painting smooth grout).
  const tiles = [];
  for (let ci = 0; ci < polys.length; ci++) {
    const poly = polys[ci];
    const polygon = [];
    const curves = [];
    for (let ei = 0; ei < poly.length; ei++) {
      const a = poly[ei];
      const b = poly[(ei + 1) % poly.length];
      const ia = vertexId.get(a);
      const ib = vertexId.get(b);
      const key = ia < ib ? `${ia}_${ib}` : `${ib}_${ia}`;
      const curve = curveByKey.get(key);
      if (!curve) {
        polygon.push(a);
        curves.push({ a, b });
      } else if (ia < ib) {
        for (let k = 0; k < curve.pts.length - 1; k++) polygon.push(curve.pts[k]);
        curves.push({ a, b, c1: curve.c1, c2: curve.c2 });
      } else {
        // Reversed traversal: reversed samples, swapped control points.
        for (let k = curve.pts.length - 1; k > 0; k--) polygon.push(curve.pts[k]);
        curves.push({ a, b, c1: curve.c2, c2: curve.c1 });
      }
    }
    tiles.push({ polygon, curves });
    await maybeYield();
  }
  return tiles;
}

/**
 * "stained-glass" tile generation — leaded glass window look.
 * Part of the built-in algorithm set; the generator contract is
 * documented in ./index.js.
 *
 * Visual goals: coarse convex glass pieces, a continuous lead network
 * whose internal vertices are degree-3 (T/Y junctions), and lead lines
 * that follow the image's strong contours like an artisan tracing the
 * design. Render with a thick borderWidth (6-10 px) and a dark
 * borderColor for the classic lead-came look.
 *
 * How the contour-following works (gradient-weighted centroidal Voronoi):
 * a Sobel gradient-magnitude field is computed from the image luminance,
 * blurred to roughly half a cell spacing so seeds can feel contours from
 * a distance. During Lloyd relaxation each seed moves toward the centroid
 * of its cell WEIGHTED by w = 1 / (1 + 24 * edgeStrength * gradient) —
 * seeds are pushed out of high-gradient zones into flat colour regions,
 * so the Voronoi bisectors between them settle onto the contours. The
 * lead lines end up describing the image while remaining a genuine
 * Voronoi diagram, which is what keeps every structural guarantee:
 * degree-3 vertices, exact coverage, and the area/side enforcement from
 * the shared generateVoronoiCells machinery.
 *
 * options.edgeStrength in [0, 1]: 0 degrades gracefully to an abstract
 * geometric stained glass (pure coarse Voronoi); 1 is full contour
 * snapping. Cell size is biased toward the upper end of
 * [minTileArea, maxTileArea] for glass-piece proportions, and
 * options.voronoiRelaxation nudges evenness as usual (at least 6 rounds
 * are always used so the weighted relaxation has time to align).
 */


/**
 * Build a normalised gradient-magnitude field at reduced resolution.
 * Returns { g, fw, fh, step } where g is Float32-like (Array) in [0, 1]
 * and (x, y) in image space maps to g[floor(y/step)*fw + floor(x/step)].
 */
function gradientField(imageData, width, height, step, blurRadius) {
  const fw = Math.max(2, Math.ceil(width / step));
  const fh = Math.max(2, Math.ceil(height / step));
  const data = imageData.data;

  // Luminance at field resolution (point-sampled at cell centres).
  const lum = new Float64Array(fw * fh);
  for (let fy = 0; fy < fh; fy++) {
    const py = Math.min(height - 1, Math.floor((fy + 0.5) * step));
    for (let fx = 0; fx < fw; fx++) {
      const px = Math.min(width - 1, Math.floor((fx + 0.5) * step));
      const p = (py * width + px) * 4;
      lum[fy * fw + fx] =
        0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2];
    }
  }

  // Sobel gradient magnitude.
  let g = new Float64Array(fw * fh);
  for (let y = 1; y < fh - 1; y++) {
    for (let x = 1; x < fw - 1; x++) {
      const i = y * fw + x;
      const gx =
        lum[i - fw + 1] + 2 * lum[i + 1] + lum[i + fw + 1] -
        lum[i - fw - 1] - 2 * lum[i - 1] - lum[i + fw - 1];
      const gy =
        lum[i + fw - 1] + 2 * lum[i + fw] + lum[i + fw + 1] -
        lum[i - fw - 1] - 2 * lum[i - fw] - lum[i - fw + 1];
      g[i] = Math.hypot(gx, gy);
    }
  }

  // Two box-blur passes (≈ Gaussian) widen the low-weight valley so seeds
  // are repelled from contours well before their cells touch them.
  const r = Math.max(1, blurRadius);
  for (let pass = 0; pass < 2; pass++) {
    const out = new Float64Array(fw * fh);
    // horizontal
    for (let y = 0; y < fh; y++) {
      for (let x = 0; x < fw; x++) {
        let sum = 0;
        let count = 0;
        for (let k = -r; k <= r; k++) {
          const xx = x + k;
          if (xx < 0 || xx >= fw) continue;
          sum += g[y * fw + xx];
          count++;
        }
        out[y * fw + x] = sum / count;
      }
    }
    // vertical
    for (let x = 0; x < fw; x++) {
      for (let y = 0; y < fh; y++) {
        let sum = 0;
        let count = 0;
        for (let k = -r; k <= r; k++) {
          const yy = y + k;
          if (yy < 0 || yy >= fh) continue;
          sum += out[yy * fw + x];
          count++;
        }
        g[y * fw + x] = sum / count;
      }
    }
  }

  let max = 0;
  for (let i = 0; i < g.length; i++) if (g[i] > max) max = g[i];
  if (max > 0) for (let i = 0; i < g.length; i++) g[i] /= max;

  return { g, fw, fh, step };
}

async function stainedGlassTiles(ctx) {
  const { width, height, minArea, maxArea, options, imageData } = ctx;
  const edgeStrength = options.edgeStrength;

  // Glass pieces sit toward the upper end of the allowed size range.
  const targetArea = Math.min(
    maxArea * 0.85,
    Math.max(maxArea * 0.75, 3 * minArea),
  );
  // Weighted relaxation needs more rounds than plain Lloyd to converge
  // onto contours (tuned: gains plateau around 6).
  const relaxation = Math.max(6, options.voronoiRelaxation + 2);

  let centroidOf; // default (undefined) = geometric centroid
  if (edgeStrength > 0 && imageData) {
    const spacing = Math.sqrt(targetArea);
    const step = Math.max(1, Math.round(spacing / 7));
    const field = gradientField(
      imageData,
      width,
      height,
      step,
      Math.max(1, Math.round(spacing / step / 3)),
    );
    const weightAt = (x, y) => {
      const fx = Math.min(field.fw - 1, Math.max(0, Math.floor(x / field.step)));
      const fy = Math.min(field.fh - 1, Math.max(0, Math.floor(y / field.step)));
      return 1 / (1 + 24 * edgeStrength * field.g[fy * field.fw + fx]);
    };

    // Gradient-weighted centroid, integrated on the field grid over the
    // (convex) cell. Falls back to the geometric centroid for degenerate
    // sampling (tiny cells between grid points).
    centroidOf = (cell) => {
      let minX = Infinity;
      let minY = Infinity;
      let maxX = -Infinity;
      let maxY = -Infinity;
      for (const [x, y] of cell) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
      let w = 0;
      let wx = 0;
      let wy = 0;
      const s = field.step;
      for (let y = minY + s / 2; y < maxY; y += s) {
        for (let x = minX + s / 2; x < maxX; x += s) {
          if (!pointInConvexPolygon(x, y, cell)) continue;
          const ww = weightAt(x, y);
          w += ww;
          wx += ww * x;
          wy += ww * y;
        }
      }
      if (w < 1e-9) return polygonCentroid(cell);
      return [wx / w, wy / w];
    };
  }

  return generateVoronoiCells(ctx, { targetArea, relaxation, centroidOf });
}

/**
 * Built-in tile-generation algorithms.
 *
 * Algorithm generator contract (also used by
 * MosaicPlugin.registerAlgorithm for custom algorithms):
 *
 *   async function generator(ctx): Promise<Array<polygon>>
 *
 * where polygon = [[x, y], ...] (convex, consistently wound) and ctx is:
 *   width, height   — image dimensions in px
 *   minArea, maxArea, maxSides — the (possibly auto-scaled) constraints
 *   rand()          — seeded PRNG in [0, 1)
 *   options         — the full options object (for algorithm extras such
 *                     as voronoiRelaxation, tangramVariation, gridShape,
 *                     curvature, edgeStrength)
 *   imageData       — the source ImageData ({ data, width, height }) for
 *                     content-aware algorithms (e.g. "stained-glass")
 *   maybeYield()    — await this inside loops so long runs don't block
 *   helpers         — { polygonArea, polygonCentroid, cleanPolygon,
 *                       splitConvexPolygon, trySplitPolygon, compactness }
 *
 * The returned polygons MUST tile the [0,width]x[0,height] rectangle with
 * no gaps or overlaps, with every tile area in [minArea, maxArea] and at
 * most maxSides sides. Neighbouring tiles must agree exactly on shared
 * boundary segments (this is what makes the grout render cleanly).
 *
 * Rich return form (used by "trencadis"): instead of a plain polygon, a
 * generator may return { polygon, curves } objects, where `polygon` is
 * the sampled outline (used for area accounting and colour sampling) and
 * `curves` is an ordered list of segments { a, b, c1?, c2? } that the
 * painter traces with bezierCurveTo (c1/c2 present) or lineTo. In that
 * form, maxSides bounds curves.length (the number of logical sides), and
 * neighbouring tiles must share identical curve geometry on common edges.
 */


const builtInAlgorithms = {
  'recursive-chord': recursiveChordTiles,
  voronoi: voronoiTiles,
  tangram: tangramTiles,
  grid: gridTiles,
  trencadis: trencadisTiles,
  'stained-glass': stainedGlassTiles,
};

/**
 * SVG serialisation — turn computed tiles into a standalone vector image.
 *
 * This is a pure serialisation step: the geometry (polygons or Bézier
 * curve segments) and colours are exactly what the canvas painter uses,
 * so the vector output matches the raster output, but scales to any size
 * without pixelation.
 *
 * Structure mirrors the canvas painter's two passes:
 *   1. A fill group — each tile is a <path> filled with its palette
 *      colour and self-stroked 1 unit in the same colour, which prevents
 *      anti-aliased hairline seams between neighbouring fills (the same
 *      trick the raster painter uses).
 *   2. A grout group (only when borderWidth > 0) — the same paths again
 *      with fill="none" and the grout stroke, stroke-linejoin="round".
 *      Paths are duplicated rather than <use>-referenced deliberately:
 *      real paths survive round-trips through vector editors far better.
 *
 * Curved tiles (trencadis) serialise their cubic segments directly to
 * SVG C commands, so grout follows the true curves at any zoom.
 */


/** Compact number formatting: fixed precision, trailing zeros stripped. */
function fmt(n, precision) {
  return String(+n.toFixed(precision));
}

/** Minimal escaping for attribute values (colours are user strings). */
function escapeAttr(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/"/g, '&quot;');
}

/** Path data for one tile: cubic C commands for curves, L for lines. */
function tilePathData(tile, precision) {
  const f = (n) => fmt(n, precision);
  if (tile.curves && tile.curves.length > 0) {
    const first = tile.curves[0];
    let d = `M${f(first.a[0])} ${f(first.a[1])}`;
    for (const seg of tile.curves) {
      if (seg.c1) {
        d +=
          `C${f(seg.c1[0])} ${f(seg.c1[1])} ` +
          `${f(seg.c2[0])} ${f(seg.c2[1])} ` +
          `${f(seg.b[0])} ${f(seg.b[1])}`;
      } else {
        d += `L${f(seg.b[0])} ${f(seg.b[1])}`;
      }
    }
    return d + 'Z';
  }
  const poly = tile.polygon;
  let d = `M${f(poly[0][0])} ${f(poly[0][1])}`;
  for (let i = 1; i < poly.length; i++) {
    d += `L${f(poly[i][0])} ${f(poly[i][1])}`;
  }
  return d + 'Z';
}

/**
 * Serialise tiles into a complete standalone SVG document string.
 *
 * @param {Object} args
 * @param {Array} args.tiles         [{ polygon, curves?, colorIndex }]
 * @param {Array} args.palette       [[r, g, b], ...]
 * @param {number} args.width        image width (px / user units)
 * @param {number} args.height       image height
 * @param {string} args.borderColor  grout colour (CSS string)
 * @param {number} args.borderWidth  grout thickness (0 = no grout group)
 * @param {number} [args.precision]  coordinate decimals (default 2)
 * @returns {string} SVG markup
 */
function tilesToSVG({
  tiles,
  palette,
  width,
  height,
  borderColor,
  borderWidth,
  precision = 2,
}) {
  const paths = tiles.map((t) => tilePathData(t, precision));

  const parts = [
    `<svg xmlns="http://www.w3.org/2000/svg" ` +
      `viewBox="0 0 ${fmt(width, precision)} ${fmt(height, precision)}" ` +
      `width="${fmt(width, precision)}" height="${fmt(height, precision)}">`,
  ];

  // Pass 1 — fills (self-stroked against anti-aliasing seams).
  parts.push('<g stroke-width="1" stroke-linejoin="round">');
  for (let i = 0; i < tiles.length; i++) {
    const [r, g, b] = palette[tiles[i].colorIndex];
    const c = `rgb(${r},${g},${b})`;
    parts.push(`<path d="${paths[i]}" fill="${c}" stroke="${c}"/>`);
  }
  parts.push('</g>');

  // Pass 2 — grout. Neighbouring tiles share boundary geometry exactly,
  // so stroking every outline yields one clean centred line per joint.
  if (borderWidth > 0) {
    parts.push(
      `<g fill="none" stroke="${escapeAttr(borderColor)}" ` +
        `stroke-width="${fmt(borderWidth, precision)}" stroke-linejoin="round">`,
    );
    for (const d of paths) parts.push(`<path d="${d}"/>`);
    parts.push('</g>');
  }

  parts.push('</svg>');
  return parts.join('\n');
}

/**
 * Shared canvas path tracing for tiles — used by the static painter and
 * the tile-by-tile animator so both draw identical geometry. Curved tiles
 * (rich form { polygon, curves }) trace their true cubic Béziers; plain
 * tiles trace their polygon.
 */


/** Begin and close a path for one tile on the given 2D context. */
function traceTilePath(ctx, tile) {
  ctx.beginPath();
  if (tile.curves && tile.curves.length > 0) {
    const first = tile.curves[0];
    ctx.moveTo(first.a[0], first.a[1]);
    for (const seg of tile.curves) {
      if (seg.c1) {
        ctx.bezierCurveTo(
          seg.c1[0], seg.c1[1],
          seg.c2[0], seg.c2[1],
          seg.b[0], seg.b[1],
        );
      } else {
        ctx.lineTo(seg.b[0], seg.b[1]);
      }
    }
  } else {
    const poly = tile.polygon;
    ctx.moveTo(poly[0][0], poly[0][1]);
    for (let i = 1; i < poly.length; i++) ctx.lineTo(poly[i][0], poly[i][1]);
  }
  ctx.closePath();
}

/**
 * Tile-by-tile mosaic animation — the original image is progressively
 * covered by tiles until the full mosaic is laid, or the reverse.
 *
 * Design: everything is built around a pure, seekable frame model.
 * seek(p) draws "the original image with the first k tiles laid on top",
 * where k follows the eased progress and a precomputed laying order.
 * play() is just a requestAnimationFrame driver over seek(), which makes
 * reverse playback (mosaic back to the original — ideal for hover
 * effects) and scrubbing free.
 *
 * The base layer under the tiles is configurable (`from`): the original
 * image (default — tiles cover it), 'transparent' (the mosaic appears
 * out of nothing, with the page showing through unlaid regions), or any
 * CSS colour for a solid backdrop.
 *
 * Exactness guarantees:
 *   - progress 0 is exactly the chosen base: the source image pixel for
 *     pixel, a fully transparent canvas, or the solid colour.
 *   - progress 1 blits the plugin's already-rendered mosaic canvas, so
 *     the final frame is pixel-identical to render() by construction —
 *     no dependence on per-tile draw-order effects.
 *   - Forward playback paints only newly-added tiles per frame (O(added)
 *     per frame); any backward seek falls back to a full redraw.
 *
 * Obtain instances via MosaicPlugin#animate(options); see that method
 * for the option reference.
 */


const ORDERS = new Set(['random', 'sweep', 'radial']);

class MosaicAnimation {
  /** @private — constructed by MosaicPlugin#animate(). */
  constructor(cfg) {
    this._tiles = cfg.tiles;
    this._palette = cfg.palette;
    this._source = cfg.sourceCanvas;
    this._from = cfg.from; // 'image' | 'transparent' | CSS colour string
    this._final = cfg.finalCanvas;
    this._width = cfg.width;
    this._height = cfg.height;
    this._borderColor = cfg.borderColor;
    this._borderWidth = cfg.borderWidth;
    this._duration = cfg.duration;
    this._easing = cfg.easing;
    this._onProgress = cfg.onProgress;
    this._raf = cfg.raf;
    this._cancelRaf = cfg.cancelRaf;
    this._now = cfg.now;

    this.canvas = cfg.targetCanvas;
    this._ctx = this.canvas.getContext('2d');

    // Precompute the laying order (deterministic per seed).
    const rand = mulberry32(cfg.seed >>> 0);
    const n = this._tiles.length;
    const order = Array.from({ length: n }, (_, i) => i);
    if (cfg.order === 'random') {
      for (let i = n - 1; i > 0; i--) {
        const j = Math.floor(rand() * (i + 1));
        [order[i], order[j]] = [order[j], order[i]];
      }
    } else {
      // 'sweep' (left to right) and 'radial' (centre outward) sort by a
      // per-tile key with organic jitter so fronts aren't razor-straight.
      const keys = new Array(n);
      for (let i = 0; i < n; i++) {
        const [cx, cy] = polygonCentroid(this._tiles[i].polygon);
        const base =
          cfg.order === 'sweep'
            ? cx / this._width
            : Math.hypot(cx - this._width / 2, cy - this._height / 2) /
              (Math.hypot(this._width, this._height) / 2);
        keys[i] = base + (rand() - 0.5) * 0.12;
      }
      order.sort((a, b) => keys[a] - keys[b]);
    }
    this._order = order;

    this._progress = 0;
    this._lastCount = -1;
    this._frameHandle = null;
    this._playing = false;

    this.seek(0);
  }

  /** Current progress in [0, 1]. */
  get progress() {
    return this._progress;
  }

  /** True while play() is advancing frames. */
  get playing() {
    return this._playing;
  }

  /** @private draw the frame base layer per the `from` mode. */
  _drawBase() {
    const ctx = this._ctx;
    ctx.clearRect(0, 0, this._width, this._height);
    if (this._from === 'image') {
      ctx.drawImage(this._source, 0, 0, this._width, this._height);
    } else if (this._from !== 'transparent') {
      ctx.fillStyle = this._from;
      ctx.fillRect(0, 0, this._width, this._height);
    }
    // 'transparent': nothing — unlaid regions stay see-through, so the
    // mosaic appears out of whatever the page shows behind the canvas.
  }

  /** @private paint one tile: fill, anti-seam self-stroke, grout. */
  _paintTile(idx) {
    const ctx = this._ctx;
    const tile = this._tiles[idx];
    const [r, g, b] = this._palette[tile.colorIndex];
    const css = `rgb(${r},${g},${b})`;
    ctx.lineJoin = 'round';
    traceTilePath(ctx, tile);
    ctx.fillStyle = css;
    ctx.strokeStyle = css;
    ctx.lineWidth = 1;
    ctx.fill();
    ctx.stroke();
    if (this._borderWidth > 0) {
      // The path persists after fill/stroke, so the grout pass reuses it.
      ctx.strokeStyle = this._borderColor;
      ctx.lineWidth = this._borderWidth;
      ctx.stroke();
    }
  }

  /**
   * Draw the frame for progress p (clamped to [0, 1]).
   * Forward motion is incremental (only newly-laid tiles are painted);
   * any backward motion does a full redraw from the source image.
   */
  seek(p) {
    const progress = Math.min(1, Math.max(0, p));
    this._progress = progress;
    const n = this._tiles.length;
    const count = Math.round(this._easing(progress) * n);

    const ctx = this._ctx;
    if (this._lastCount >= 0 && count >= this._lastCount) {
      for (let i = this._lastCount; i < count; i++) {
        this._paintTile(this._order[i]);
      }
    } else {
      this._drawBase();
      for (let i = 0; i < count; i++) {
        this._paintTile(this._order[i]);
      }
    }
    // At the end, blit the real render so the last frame is exactly it.
    // clearRect first: the render canvas contains a few partial-alpha
    // anti-aliased pixels, and drawing those OVER the animation frame
    // would blend rather than replace — clearing makes the blit a copy.
    if (progress >= 1) {
      ctx.clearRect(0, 0, this._width, this._height);
      ctx.drawImage(this._final, 0, 0);
    }
    this._lastCount = count;
    if (this._onProgress) this._onProgress(progress);
    return this;
  }

  /**
   * Animate from the current progress to 1 (or to 0 when
   * { reverse: true }) at a rate of one full sweep per `duration` ms.
   * @returns {Promise<MosaicAnimation>} resolves when the end is reached
   *   (or immediately on pause()/cancel()).
   */
  play({ reverse = false } = {}) {
    this.pause();
    this._playing = true;
    return new Promise((resolve) => {
      let prev = this._now();
      const step = () => {
        const t = this._now();
        const dt = (t - prev) / this._duration;
        prev = t;
        const next = this._progress + (reverse ? -dt : dt);
        this.seek(next);
        const done = reverse ? this._progress <= 0 : this._progress >= 1;
        if (done || !this._playing) {
          this._playing = false;
          this._frameHandle = null;
          resolve(this);
        } else {
          this._frameHandle = this._raf(step);
        }
      };
      this._frameHandle = this._raf(step);
    });
  }

  /** Stop advancing, keeping the current frame. */
  pause() {
    this._playing = false;
    if (this._frameHandle != null) {
      this._cancelRaf(this._frameHandle);
      this._frameHandle = null;
    }
    return this;
  }

  /** Stop and reset to the source image (progress 0). */
  cancel() {
    this.pause();
    this.seek(0);
    return this;
  }
}

/**
 * MosaicPlugin — turn any image into a flat-colour polygonal mosaic.
 *
 * Framework-agnostic, dependency-free, Canvas-2D only.
 * Works in the browser (window / Web Worker with OffscreenCanvas) and in
 * Node.js when a canvas factory is injected via `options.createCanvas`.
 *
 * Pipeline:
 *   1. Load the source image and read its pixels.
 *   2. Extract a palette of `maxColors` dominant colours (median-cut,
 *      see ./palette.js).
 *   3. Tessellate the image rectangle into irregular convex polygons
 *      ("tiles") with the selected `algorithm`, honouring minTileArea,
 *      maxTileArea and maxSides (see ./algorithms/).
 *   4. Colour each tile with the palette entry nearest to the average of
 *      a few samples taken from the original image inside the tile.
 *   5. Paint tiles, then stroke shared edges with the grout colour.
 *      After render(), toSVG() serialises the same geometry to a
 *      standalone vector document (see ./svg.js), and animate() lays the
 *      tiles progressively over the original image (see ./animate.js).
 *
 * Tile-generation algorithms (options.algorithm) — each lives in its own
 * module under ./algorithms/ and is documented there:
 *   - "voronoi" (default): organic cellular cracks; no edge can span the
 *     image. `voronoiRelaxation` controls cell evenness.
 *   - "recursive-chord": angular, shard-like top-down splitting; long
 *     straight fractures are inherent to this style.
 *   - "tangram": the 7 classic Chinese-puzzle pieces tiled in pattern
 *     cells; `tangramVariation` controls rotation/mirroring/row offsets.
 *   - "grid": uniform ceramic tiles; `gridShape` selects squares,
 *     running-bond bricks ("subway tile"), or stacked rectangles.
 *   - "trencadis": Gaudí-style broken ceramic — a curved-edge Voronoi
 *     where pieces can be concave and grout follows the curves;
 *     `curvature` (0-1) controls how far edges bow, and
 *     `voronoiRelaxation` shapes the underlying layout.
 *   - "stained-glass": leaded glass window — coarse convex pieces whose
 *     lead lines follow the image's contours; `edgeStrength` (0-1) sets
 *     how strongly (0 = abstract geometric glass). Pair with a thick
 *     borderWidth and dark borderColor for the lead came.
 *   Additional algorithms can be plugged in with
 *   MosaicPlugin.registerAlgorithm(name, generatorFn) — the generator
 *   contract is documented in ./algorithms/index.js.
 *
 * @example
 *   const mosaic = new MosaicPlugin({
 *     image: document.getElementById('source-img'),
 *     maxColors: 16,
 *     maxTileArea: 2000,
 *     minTileArea: 300,
 *     maxSides: 8,
 *     borderColor: '#333333',
 *     borderWidth: 3,
 *     algorithm: 'voronoi',
 *   });
 *   const canvas = await mosaic.render();
 *   document.body.appendChild(canvas);
 */


const DEFAULTS = {
  maxColors: 16,
  maxTileArea: 2000,
  minTileArea: 300,
  maxSides: 8,
  borderColor: '#333333',
  borderWidth: 3,
  algorithm: 'voronoi', // 'voronoi' | 'recursive-chord' | 'tangram' | 'grid' | registered
  voronoiRelaxation: 2, // Lloyd iterations: 0 = wilder cells, 5 = very even
  tangramVariation: 2, // 0 uniform | 1 +rotations | 2 +mirroring | 3 +row offset
  gridShape: 'square', // grid only: 'square' | 'brick' | 'stacked-rectangle'
  curvature: 0.65, // trencadis only: 0 = straight edges .. 1 = maximal bow
  edgeStrength: 0.75, // stained-glass only: 0 abstract .. 1 full contour snap
  seed: null, // number for reproducible mosaics; null = random each render
  createCanvas: null, // (w, h) => canvas — override for Node / testing
  yieldEveryMs: 12, // main-thread budget per chunk before yielding
};

class MosaicPlugin {
  /**
   * @param {Object} options — see DEFAULTS and the README for details.
   */
  constructor(options) {
    if (!options || typeof options !== 'object') {
      throw new TypeError('MosaicPlugin: an options object is required.');
    }
    this.options = { ...DEFAULTS, ...options };
    this._validateOptions();
    this._canvas = null;
    this._tiles = null;
    this._palette = null;
  }

  /**
   * Register a custom tile-generation algorithm.
   * See the "Algorithm generator contract" comment above for the generator
   * signature; after registration, pass its name as `options.algorithm`.
   *
   * @param {string} name
   * @param {Function} generator  async (ctx) => Array<polygon>
   */
  static registerAlgorithm(name, generator) {
    if (typeof name !== 'string' || !name.trim()) {
      throw new TypeError('registerAlgorithm: `name` must be a non-empty string.');
    }
    if (typeof generator !== 'function') {
      throw new TypeError('registerAlgorithm: `generator` must be a function.');
    }
    MosaicPlugin.algorithms[name] = generator;
  }

  /* ----------------------------- public API ----------------------------- */

  /**
   * Run the full pipeline.
   * @returns {Promise<HTMLCanvasElement|OffscreenCanvas>} the mosaic canvas.
   */
  async render() {
    const o = this.options;
    const rand = mulberry32(
      o.seed == null ? (Math.random() * 0xffffffff) >>> 0 : o.seed >>> 0,
    );

    // 1. Load source pixels.
    const { width, height, imageData } = await this._loadImage(o.image);

    // Robustness for small images: scale tile bounds down so at least a
    // handful of tiles fit; refuse images too small to mosaic at all.
    let { minTileArea, maxTileArea } = o;
    const imgArea = width * height;
    if (imgArea < 16 * 16) {
      throw new RangeError(
        `MosaicPlugin: image is too small to mosaic (${width}x${height}px; ` +
          'need at least 16x16).',
      );
    }
    if (maxTileArea > imgArea / 4) {
      const scale = imgArea / 4 / maxTileArea;
      maxTileArea = Math.max(8, maxTileArea * scale);
      minTileArea = Math.max(2, minTileArea * scale);
      if (typeof console !== 'undefined' && console.warn) {
        console.warn(
          'MosaicPlugin: tile areas scaled down to fit a small image ' +
            `(maxTileArea -> ${maxTileArea.toFixed(1)}, ` +
            `minTileArea -> ${minTileArea.toFixed(1)}).`,
        );
      }
    }

    // 2. Palette.
    const stride = Math.max(1, Math.floor(imgArea / 60000));
    this._palette = medianCutPalette(imageData.data, o.maxColors, stride);
    await this._yield();

    // 3. Tessellate with the selected algorithm.
    const generator = MosaicPlugin.algorithms[o.algorithm];
    let clock = Date.now();
    const maybeYield = async () => {
      if (Date.now() - clock >= o.yieldEveryMs) {
        await this._yield();
        clock = Date.now();
      }
    };
    const polygons = await generator({
      width,
      height,
      minArea: minTileArea,
      maxArea: maxTileArea,
      maxSides: o.maxSides,
      rand,
      options: o,
      imageData,
      maybeYield,
      helpers: {
        polygonArea,
        polygonCentroid,
        cleanPolygon,
        splitConvexPolygon,
        trySplitPolygon,
        compactness,
      },
    });
    const tiles = polygons.map((p) =>
      Array.isArray(p)
        ? { polygon: p, curves: null, colorIndex: 0 }
        : { polygon: p.polygon, curves: p.curves || null, colorIndex: 0 },
    );

    // 4. Colour tiles.
    await this._colourTiles(tiles, imageData, width, height, rand);
    this._tiles = tiles;

    this._width = width;
    this._height = height;

    // 5. Paint.
    this._canvas = this._makeCanvas(width, height);
    await this._paint(this._canvas, tiles, o.borderColor, o.borderWidth);

    return this._canvas;
  }

  /**
   * Data URL of the last render.
   * @param {string} [type='image/png']
   * @param {number} [quality]
   */
  toDataURL(type = 'image/png', quality) {
    if (!this._canvas) {
      throw new Error('MosaicPlugin: call render() before toDataURL().');
    }
    if (typeof this._canvas.toDataURL !== 'function') {
      throw new Error(
        'MosaicPlugin: this canvas type has no toDataURL(); ' +
          'use canvas.convertToBlob() (OffscreenCanvas) instead.',
      );
    }
    return this._canvas.toDataURL(type, quality);
  }

  /**
   * Vector export of the last render: a standalone SVG document in which
   * every tile is a <path> with its flat palette fill, and the grout is a
   * second stroke pass (stroke-linejoin="round"). Curved tiles serialise
   * their cubic Béziers to SVG C commands, so the result scales to any
   * size without pixelation — ideal for print or vector editing.
   *
   * @param {Object} [opts]
   * @param {number} [opts.precision=2] coordinate decimal places
   * @returns {string} SVG markup (wrap in a Blob for downloads:
   *   new Blob([svg], { type: 'image/svg+xml' }))
   */
  toSVG({ precision = 2 } = {}) {
    if (!this._tiles) {
      throw new Error('MosaicPlugin: call render() before toSVG().');
    }
    return tilesToSVG({
      tiles: this._tiles,
      palette: this._palette,
      width: this._width,
      height: this._height,
      borderColor: this.options.borderColor,
      borderWidth: this.options.borderWidth,
      precision,
    });
  }

  /**
   * Tile-by-tile animation from the original image to the mosaic — built
   * for use as a page effect (e.g. animating an artist's images into
   * mosaics on hover). Auto-renders first if render() hasn't run.
   *
   * The returned controller is seekable, so playing in reverse (mosaic
   * back to the original) and scrubbing work out of the box:
   *
   *   const anim = await mosaic.animate({ duration: 2500 });
   *   container.appendChild(anim.canvas);
   *   el.addEventListener('mouseenter', () => anim.play());
   *   el.addEventListener('mouseleave', () => anim.play({ reverse: true }));
   *
   * Guarantees: progress 0 is the source image pixel-for-pixel; progress
   * 1 blits the render() canvas, so the final frame is exactly the
   * static mosaic.
   *
   * @param {Object} [opts]
   * @param {HTMLCanvasElement} [opts.canvas] target canvas (created and
   *   exposed as controller.canvas when omitted; sized to the image)
   * @param {number} [opts.duration=2500] ms for one full sweep
   * @param {string} [opts.order='random'] laying order: 'random',
   *   'sweep' (left to right), or 'radial' (centre outward)
   * @param {string} [opts.from='image'] base layer under the tiles:
   *   'image' (the original, progressively covered), 'transparent' (the
   *   mosaic appears out of nothing — unlaid regions stay see-through),
   *   or any CSS colour string for a solid backdrop
   * @param {Function} [opts.easing] progress easing (t in [0,1]) -> [0,1]
   * @param {Function} [opts.onProgress] called with progress each frame
   * @param {number} [opts.seed] laying-order seed (defaults to the
   *   plugin seed, or random)
   * @returns {Promise<MosaicAnimation>} controller with seek(p), play(),
   *   play({ reverse: true }), pause(), cancel(), .canvas, .progress
   */
  async animate(opts = {}) {
    if (!this._tiles) await this.render();

    const fail = (msg) => {
      throw new RangeError(`MosaicPlugin: ${msg}`);
    };
    const duration = opts.duration == null ? 2500 : opts.duration;
    if (!(typeof duration === 'number') || !(duration > 0)) {
      fail('animate `duration` must be a positive number of milliseconds.');
    }
    const order = opts.order == null ? 'random' : opts.order;
    if (!ORDERS.has(order)) {
      fail(
        `animate \`order\` must be one of "${[...ORDERS].join('", "')}".`,
      );
    }
    const from = opts.from == null ? 'image' : opts.from;
    if (typeof from !== 'string' || from.trim() === '') {
      fail(
        "animate `from` must be 'image', 'transparent', or a CSS colour string.",
      );
    }
    const easing = opts.easing == null ? (t) => t : opts.easing;
    if (typeof easing !== 'function') fail('animate `easing` must be a function.');
    if (opts.onProgress != null && typeof opts.onProgress !== 'function') {
      fail('animate `onProgress` must be a function.');
    }

    let targetCanvas = opts.canvas;
    if (targetCanvas) {
      targetCanvas.width = this._width;
      targetCanvas.height = this._height;
    } else {
      targetCanvas = this._makeCanvas(this._width, this._height);
    }

    // Frame scheduling is injectable so the animation is testable in
    // Node; in browsers it defaults to requestAnimationFrame.
    const hasRaf = typeof requestAnimationFrame === 'function';
    const raf =
      opts.raf || (hasRaf ? (cb) => requestAnimationFrame(cb) : (cb) => setTimeout(cb, 16));
    const cancelRaf =
      opts.cancelRaf ||
      (hasRaf ? (id) => cancelAnimationFrame(id) : (id) => clearTimeout(id));
    const now =
      opts.now ||
      (typeof performance !== 'undefined' && performance.now
        ? () => performance.now()
        : () => Date.now());

    let seed = opts.seed != null ? opts.seed : this.options.seed;
    if (seed == null) seed = (Math.random() * 0xffffffff) >>> 0;

    return new MosaicAnimation({
      tiles: this._tiles,
      palette: this._palette,
      sourceCanvas: this._sourceCanvas,
      finalCanvas: this._canvas,
      width: this._width,
      height: this._height,
      borderColor: this.options.borderColor,
      borderWidth: this.options.borderWidth,
      duration,
      order,
      from,
      easing,
      onProgress: opts.onProgress || null,
      seed,
      targetCanvas,
      raf,
      cancelRaf,
      now,
    });
  }

  /** The extracted palette of the last render, as [r,g,b] triplets. */
  get palette() {
    return this._palette ? this._palette.map((c) => [...c]) : null;
  }

  /** The generated tiles of the last render: {polygon, colorIndex}. */
  get tiles() {
    return this._tiles;
  }

  /* ----------------------------- validation ----------------------------- */

  _validateOptions() {
    const o = this.options;
    const fail = (msg) => {
      throw new RangeError(`MosaicPlugin: ${msg}`);
    };

    if (o.image == null) fail('`image` is required.');
    if (!Number.isInteger(o.maxColors) || o.maxColors < 1) {
      fail('`maxColors` must be an integer >= 1.');
    }
    if (!(typeof o.maxTileArea === 'number') || !(o.maxTileArea > 0)) {
      fail('`maxTileArea` must be a positive number (px^2).');
    }
    if (!(typeof o.minTileArea === 'number') || !(o.minTileArea > 0)) {
      fail('`minTileArea` must be a positive number (px^2).');
    }
    if (o.minTileArea >= o.maxTileArea) {
      fail('`minTileArea` must be smaller than `maxTileArea`.');
    }
    if (o.maxTileArea < 2 * o.minTileArea) {
      fail(
        '`maxTileArea` must be at least 2 x `minTileArea`, otherwise a tile ' +
          'above the maximum cannot be split into two tiles above the minimum.',
      );
    }
    if (!Number.isInteger(o.maxSides) || o.maxSides < 3) {
      fail('`maxSides` must be an integer >= 3.');
    }
    if (typeof o.borderColor !== 'string' || o.borderColor.trim() === '') {
      fail('`borderColor` must be a CSS colour string.');
    }
    if (!(typeof o.borderWidth === 'number') || o.borderWidth < 0) {
      fail('`borderWidth` must be a number >= 0.');
    }
    if (typeof o.algorithm !== 'string' || !MosaicPlugin.algorithms[o.algorithm]) {
      const names = Object.keys(MosaicPlugin.algorithms).join('", "');
      fail(`\`algorithm\` must be one of "${names}".`);
    }
    if (
      !Number.isInteger(o.voronoiRelaxation) ||
      o.voronoiRelaxation < 0 ||
      o.voronoiRelaxation > 5
    ) {
      fail('`voronoiRelaxation` must be an integer between 0 and 5.');
    }
    if (
      !Number.isInteger(o.tangramVariation) ||
      o.tangramVariation < 0 ||
      o.tangramVariation > 3
    ) {
      fail('`tangramVariation` must be an integer between 0 and 3.');
    }
    if (!['square', 'brick', 'stacked-rectangle'].includes(o.gridShape)) {
      fail(
        "`gridShape` must be 'square', 'brick', or 'stacked-rectangle'.",
      );
    }
    if (
      !(typeof o.curvature === 'number') ||
      !Number.isFinite(o.curvature) ||
      o.curvature < 0 ||
      o.curvature > 1
    ) {
      fail('`curvature` must be a number between 0 and 1.');
    }
    if (
      !(typeof o.edgeStrength === 'number') ||
      !Number.isFinite(o.edgeStrength) ||
      o.edgeStrength < 0 ||
      o.edgeStrength > 1
    ) {
      fail('`edgeStrength` must be a number between 0 and 1.');
    }
    if (o.seed != null && !Number.isFinite(o.seed)) {
      fail('`seed` must be a finite number or null.');
    }
  }

  /* ----------------------------- image loading ----------------------------- */

  _makeCanvas(w, h) {
    if (typeof this.options.createCanvas === 'function') {
      return this.options.createCanvas(w, h);
    }
    if (typeof document !== 'undefined') {
      const c = document.createElement('canvas');
      c.width = w;
      c.height = h;
      return c;
    }
    if (typeof OffscreenCanvas !== 'undefined') {
      return new OffscreenCanvas(w, h);
    }
    throw new Error(
      'MosaicPlugin: no canvas available. In Node, pass options.createCanvas.',
    );
  }

  async _loadImage(source) {
    let img = source;

    if (typeof source === 'string') {
      // URL string -> load it.
      if (typeof Image !== 'undefined') {
        img = await new Promise((resolve, reject) => {
          const el = new Image();
          el.crossOrigin = 'anonymous';
          el.onload = () => resolve(el);
          el.onerror = () =>
            reject(new Error(`MosaicPlugin: failed to load image "${source}".`));
          el.src = source;
        });
      } else if (typeof fetch !== 'undefined' && typeof createImageBitmap !== 'undefined') {
        const res = await fetch(source);
        if (!res.ok) {
          throw new Error(`MosaicPlugin: failed to fetch image "${source}".`);
        }
        img = await createImageBitmap(await res.blob());
      } else {
        throw new Error(
          'MosaicPlugin: cannot load a URL in this environment; ' +
            'pass a decoded image or canvas instead.',
        );
      }
    }

    // Wait for <img> elements that are still decoding.
    if (typeof HTMLImageElement !== 'undefined' && img instanceof HTMLImageElement) {
      if (!img.complete) {
        await new Promise((resolve, reject) => {
          img.addEventListener('load', resolve, { once: true });
          img.addEventListener(
            'error',
            () => reject(new Error('MosaicPlugin: the <img> failed to load.')),
            { once: true },
          );
        });
      }
      if (!img.naturalWidth) {
        throw new Error('MosaicPlugin: the <img> has no decoded pixel data.');
      }
    }

    const width = img.naturalWidth || img.width;
    const height = img.naturalHeight || img.height;
    if (!width || !height) {
      throw new Error('MosaicPlugin: could not determine image dimensions.');
    }

    const canvas = this._makeCanvas(width, height);
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(img, 0, 0, width, height);
    // Kept for animate(): frames start from the decoded source pixels.
    this._sourceCanvas = canvas;
    let imageData;
    try {
      imageData = ctx.getImageData(0, 0, width, height);
    } catch (err) {
      throw new Error(
        'MosaicPlugin: cannot read image pixels — the canvas is tainted. ' +
          'Serve the image with CORS headers or from the same origin.',
      );
    }
    return { width, height, imageData };
  }

  /* ----------------------------- colouring ----------------------------- */

  async _colourTiles(tiles, imageData, width, height, rand) {
    const data = imageData.data;
    const readPixel = (x, y) => {
      const px = Math.min(width - 1, Math.max(0, Math.round(x)));
      const py = Math.min(height - 1, Math.max(0, Math.round(y)));
      const p = (py * width + px) * 4;
      return [data[p], data[p + 1], data[p + 2]];
    };

    let clock = Date.now();
    for (const tile of tiles) {
      const poly = tile.polygon;
      const [cx, cy] = polygonCentroid(poly);

      // Sample the centroid plus a few random interior points, then average.
      let r = 0;
      let g = 0;
      let b = 0;
      let count = 0;
      const addSample = (x, y) => {
        const [sr, sg, sb] = readPixel(x, y);
        r += sr;
        g += sg;
        b += sb;
        count++;
      };
      if (pointInPolygon(cx, cy, poly)) addSample(cx, cy);

      // Bounding box for rejection sampling.
      let minX = Infinity;
      let minY = Infinity;
      let maxX = -Infinity;
      let maxY = -Infinity;
      for (const [x, y] of poly) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
      const wanted = 6;
      for (let s = 0, guard = 0; s < wanted && guard < 40; guard++) {
        const x = minX + rand() * (maxX - minX);
        const y = minY + rand() * (maxY - minY);
        if (pointInPolygon(x, y, poly)) {
          addSample(x, y);
          s++;
        }
      }
      if (count === 0) addSample(cx, cy); // concave fallback: never divide by 0

      tile.colorIndex = nearestPaletteIndex(
        this._palette,
        r / count,
        g / count,
        b / count,
      );

      if (Date.now() - clock >= this.options.yieldEveryMs) {
        await this._yield();
        clock = Date.now();
      }
    }
  }

  /* ----------------------------- painting ----------------------------- */

  async _paint(canvas, tiles, borderColor, borderWidth) {
    const ctx = canvas.getContext('2d');
    const palette = this._palette;

    const traceTile = (tile) => traceTilePath(ctx, tile);

    // Pass 1 — fill every tile. Each fill is also stroked 1px in its own
    // colour so anti-aliased seams between neighbours don't show through
    // when borderWidth is 0.
    ctx.lineJoin = 'round';
    let clock = Date.now();
    for (const tile of tiles) {
      const [r, g, b] = palette[tile.colorIndex];
      const css = `rgb(${r},${g},${b})`;
      ctx.fillStyle = css;
      ctx.strokeStyle = css;
      ctx.lineWidth = 1;
      traceTile(tile);
      ctx.fill();
      ctx.stroke();
      if (Date.now() - clock >= this.options.yieldEveryMs) {
        await this._yield();
        clock = Date.now();
      }
    }

    // Pass 2 — grout. Because neighbouring tiles share their boundary
    // segments exactly, stroking every tile outline draws one clean,
    // centred grout line per shared edge.
    if (borderWidth > 0) {
      ctx.strokeStyle = borderColor;
      ctx.lineWidth = borderWidth;
      clock = Date.now();
      for (const tile of tiles) {
        traceTile(tile);
        ctx.stroke();
        if (Date.now() - clock >= this.options.yieldEveryMs) {
          await this._yield();
          clock = Date.now();
        }
      }
    }
  }

  /* ----------------------------- misc ----------------------------- */

  _yield() {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }
}

/** Built-in tile-generation algorithms. Extend via registerAlgorithm(). */
MosaicPlugin.algorithms = { ...builtInAlgorithms };

export { MosaicPlugin as default };
//# sourceMappingURL=mosaic-plugin.esm.js.map
