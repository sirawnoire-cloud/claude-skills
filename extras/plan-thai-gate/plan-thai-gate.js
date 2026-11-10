#!/usr/bin/env node
// PreToolUse gate on ExitPlanMode: when pordee mode is on, require the plan the user is about
// to read to actually be terse Thai, not just "reminded" to be — pordee's own UserPromptSubmit
// injection is a request the model can and does drift away from for plan documents specifically
// (plans read as a more formal/technical artifact, which pulls the model back toward default
// English professional-writing habits). This is the mechanical gate pordee itself doesn't have.
//
// Mirrors skill-smith's own hook contract: exit 0 silent = allow, exit 2 + stderr = block with
// a reason the model sees and can act on. Never blocks more than twice on the same plan file —
// a miscalibrated heuristic must not be able to loop the model forever.
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORDEE_HOME = process.env.PORDEE_HOME || path.join(os.homedir(), '.pordee');
const STATE_PATH = path.join(PORDEE_HOME, 'state.json');
const PLANS_DIR = path.join(os.homedir(), '.claude', 'plans');
const GATE_STATE_PATH = path.join(os.homedir(), '.claude', 'hooks', '.plan-thai-gate-state.json');
const STALE_MS = 5 * 60 * 1000; // a plan file older than this wasn't just written for this turn
const MAX_BLOCKS_PER_FILE = 2;

function allow() { process.exit(0); }

function block(reason) {
  process.stderr.write(reason + '\n');
  process.exit(2);
}

function pordeeEnabled() {
  try {
    if (!fs.existsSync(STATE_PATH)) return false;
    const s = JSON.parse(fs.readFileSync(STATE_PATH, 'utf8'));
    return s.enabled === true;
  } catch (e) {
    return false; // can't confirm pordee is on — don't gate
  }
}

function mostRecentPlanFile() {
  let entries;
  try {
    entries = fs.readdirSync(PLANS_DIR)
      .filter((f) => f.endsWith('.md'))
      .map((f) => {
        const p = path.join(PLANS_DIR, f);
        return { p, mtime: fs.statSync(p).mtimeMs };
      });
  } catch (e) {
    return null;
  }
  if (entries.length === 0) return null;
  entries.sort((a, b) => b.mtime - a.mtime);
  const newest = entries[0];
  if (Date.now() - newest.mtime > STALE_MS) return null; // nothing fresh — not this turn's plan
  return newest.p;
}

// Strip fenced/inline code, paths, and URLs before judging "is this Thai / is this fluffy" —
// technical tokens are supposed to stay in English (pordee's own rule), so they must not count
// against the plan.
function stripCodeAndTechnical(text) {
  return text
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`[^`]*`/g, ' ')
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/(?:[\w.-]+\/)+[\w.-]+/g, ' ') // path-like tokens
    .replace(/^#{1,6}\s.*$/gm, ' '); // headings are structure, not prose to judge
}

function thaiRatio(prose) {
  const thai = (prose.match(/[฀-๿]/g) || []).length;
  const latinAlpha = (prose.match(/[A-Za-z]/g) || []).length;
  const total = thai + latinAlpha;
  if (total < 40) return null; // too little prose to judge meaningfully either way
  return thai / total;
}

const FILLER_PATTERNS = [
  // English
  /\bin order to\b/gi, /\bit is important to note\b/gi, /\bplease note that\b/gi,
  /\bas (?:previously |already )?mentioned\b/gi, /\bit should be noted\b/gi,
  /\badditionally,\b/gi, /\bfurthermore,\b/gi, /\bbasically\b/gi, /\bessentially\b/gi,
  // Thai hedging/filler pordee itself already targets
  /อาจจะ/g, /น่าจะ/g, /จริงๆแล้ว/g, /โดยพื้นฐานแล้ว/g, /ได้เลยครับ/g, /แน่นอนครับ/g,
  /อย่างไรก็ตาม/g, /ดังที่กล่าวมาแล้ว/g, /ดังที่ได้กล่าวไปข้างต้น/g,
];

function fillerHits(prose) {
  return FILLER_PATTERNS.reduce((n, re) => n + (prose.match(re) || []).length, 0);
}

function loadGateState() {
  try {
    return JSON.parse(fs.readFileSync(GATE_STATE_PATH, 'utf8'));
  } catch (e) {
    return {};
  }
}

function saveGateState(s) {
  try {
    fs.mkdirSync(path.dirname(GATE_STATE_PATH), { recursive: true });
    fs.writeFileSync(GATE_STATE_PATH, JSON.stringify(s));
  } catch (e) {
    // best-effort — losing the counter just means the escape hatch resets, not a failure mode
  }
}

function main() {
  if (!pordeeEnabled()) return allow();

  const file = mostRecentPlanFile();
  if (!file) return allow(); // no plan file to judge — nothing this hook can do here

  let raw;
  try {
    raw = fs.readFileSync(file, 'utf8');
  } catch (e) {
    return allow();
  }

  const prose = stripCodeAndTechnical(raw);
  const ratio = thaiRatio(prose);
  const fillers = fillerHits(prose);
  const wordCount = (prose.match(/\S+/g) || []).length;
  const fillerRate = wordCount > 0 ? fillers / wordCount : 0;

  // Conservative thresholds, deliberately: a missed catch just matches today's status quo, a
  // false block disrupts a plan that was already fine. Only flag clear cases.
  const problems = [];
  if (ratio !== null && ratio < 0.15) {
    problems.push('เนื้อหาส่วนใหญ่เป็นภาษาอังกฤษล้วน (สัดส่วนไทยในข้อความ ~' +
      Math.round(ratio * 100) + '%) — เขียนเป็นไทยกระชับ เก็บ technical term/code/path ไว้เป็นอังกฤษตามเดิม');
  }
  if (fillerRate > 0.015 && fillers >= 3) {
    problems.push('มีคำฟุ่มเฟือย/hedging เกินจำเป็น (' + fillers + ' จุด) — ตัดออก เหลือแต่เนื้อหา (ดู pordee drop-list: ' +
      'อาจจะ/น่าจะ/จริงๆแล้ว/ได้เลยครับ/แน่นอนครับ และ English filler เช่น "in order to", "it should be noted")');
  }

  if (problems.length === 0) return allow();

  const gs = loadGateState();
  const prior = gs[file] || 0;
  if (prior >= MAX_BLOCKS_PER_FILE) {
    // Already pushed back twice on this exact plan — stop insisting, let the user see it.
    return allow();
  }
  gs[file] = prior + 1;
  saveGateState(gs);

  return block(
    'pordee: plan ที่กำลังจะแสดงให้ user อ่าน (' + path.basename(file) + ') ยังไม่ผ่าน:\n' +
    problems.map((p) => '  - ' + p).join('\n') + '\n' +
    'แก้ไฟล์แผนตรงนี้ก่อน แล้วเรียก ExitPlanMode ใหม่ — โครงสร้าง/หัวข้อ/การตัดสินใจทั้งหมดเก็บไว้เหมือนเดิม แค่เขียนให้กระชับและเป็นไทยขึ้น.'
  );
}

main();
