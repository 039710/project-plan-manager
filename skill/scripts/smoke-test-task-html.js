// Smoke check for project-plan-manager dashboard template.
// Run: node <this-file> [path/to/task.html]
const fs = require("fs"), path = require("path");
const file = process.argv[2] || path.join(__dirname, "..", "templates", "task.html");
const html = fs.readFileSync(file, "utf8");
const src = html.split(/^  <script>$/m)[1].split(/^  <\/script>$/m)[0];
if (!src) { console.error("script block not found"); process.exit(1); }

const mk = () => ({ innerHTML:"", textContent:"", hidden:false, open:false, value:"", className:"",
  dataset:{}, classList:{add(){},remove(){}}, addEventListener(){}, showModal(){}, close(){}, setAttribute(){} });
const nodes = new Map();
const document = {
  documentElement: mk(),
  querySelector: sel => { if (!nodes.has(sel)) nodes.set(sel, mk()); return nodes.get(sel); },
  querySelectorAll: () => [],
};
const localStorage = { store:{ "ppm-theme":"dark", "ppm-cols":"2" }, getItem(k){return this.store[k] ?? null;}, setItem(k,v){this.store[k]=String(v);} };
const matchMedia = () => ({ matches:false, addEventListener(){} });
const api = new Function("document","localStorage","navigator","setInterval","clearInterval","window","fetch",
  src + "\n; return { state, render, taskActions, phaseLabel };")(document, localStorage, { clipboard:{ writeText: async()=>{} } },
  () => 0, () => {}, { prompt(){}, matchMedia }, async () => ({ ok:true, text: async () => '{"projects":[]}' }));

api.state.data = { projects: [ { id:"p1", name:"demo", path:"/tmp/demo", plans: [ { name:"alpha", content:"# alpha",
  phases: [ { name:"phase_0", title:"P0", tasks: [
    { id:"TASK-001", title:"ok task", detail:"do it", status:"todo", progress:"" },
    { id:"TASK-002", title:"bad task", detail:"broke", status:"fail", progress:"boom" },
    { id:"TASK-003", title:"done", detail:"x", status:"completed", progress:"done" } ] } ] } ] } ] };
api.state.project = "p1";
api.render();
const out = document.querySelector("#content").innerHTML;
const checks = [
  ["fail task forced open",   out.includes('data-key="p1/alpha/phase_0/TASK-002" data-forced="1" open')],
  ["plan forced open",        out.includes('data-key="p1/alpha" data-forced="1" open')],
  ["todo task starts closed", out.includes('data-key="p1/alpha/phase_0/TASK-001"><summary>')],
  ["task actions rendered",   (out.match(/task-actions/g) || []).length === 3],
  ["execute prompt",          out.includes("Execute TASK-001 (ok task) in alpha/phase_0 using Project-Plan-Manager skill")],
  ["cli prompt",              out.includes("plan-task task_get_detail --plan alpha --phase phase_0 --task-id TASK-003")],
  ["detail prompt",           out.includes("[TASK-002] bad task") && out.includes("Progress:\nboom")],
  ["icon + aria-label",       out.includes('class="ico"') && out.includes('aria-label="Copy CLI"')],
  ["glyph per task",          out.match(/class="glyph"/g)?.length === 3],
  ["status labels",           ["To do", "Failed", "Done"].every(l => out.includes(`>${l}<`))],
  ["phase strip segments",    out.match(/class="segp /g)?.length === 1 && out.includes('title="phase-0: ') && out.includes("segp fail")],
  ["phase label mapped",      out.includes("phase-0: 1 of 3 done") && api.phaseLabel("phase_12") === "phase-12"],
  ["plan meta no middle dot", !out.includes("&middot;") && out.includes("</b> of 3 done, 33%")],
  ["theme dark applied",      document.documentElement.dataset.theme === "dark"],
  ["cols from storage",       document.querySelector("#cols").value === "2" && document.querySelector("#content").className === "wrap cols-2"],
];
api.state.query = "ok task";
api.render();
const searched = document.querySelector("#content").innerHTML;
checks.push(["search auto-opens match", searched.includes('data-key="p1/alpha/phase_0/TASK-001" data-forced="1" open')]);
checks.push(["search hides non-match", !searched.includes("TASK-003")]);

// Example plan contract checks. Skipped when running from an installed skill
// copy, which carries skill/ only and has no examples/ directory.
const examplesDir = path.join(__dirname, "..", "..", "examples", "demo-plan");
if (fs.existsSync(examplesDir)) {
  const tasksDir = path.join(examplesDir, "tasks");
  const phaseFiles = fs.existsSync(tasksDir) ? fs.readdirSync(tasksDir).filter(name => name.endsWith(".json")) : [];
  checks.push(["example plan.md present", fs.existsSync(path.join(examplesDir, "plan.md"))]);
  checks.push(["example has >=2 phases", phaseFiles.length >= 2]);
  let contractOk = phaseFiles.length > 0;
  for (const name of phaseFiles) {
    const data = JSON.parse(fs.readFileSync(path.join(tasksDir, name), "utf8"));
    if (data.phase !== name.replace(/\.json$/, "")) contractOk = false;
    if (!Array.isArray(data.tasks) || data.tasks.length === 0) contractOk = false;
    const ids = new Set();
    for (const task of data.tasks || []) {
      if (typeof task.id !== "string" || ids.has(task.id)) contractOk = false;
      ids.add(task.id);
      if (typeof task.title !== "string" || typeof task.detail !== "string" || typeof task.progress !== "string") contractOk = false;
      if (!["todo", "completed", "fail"].includes(task.status)) contractOk = false;
    }
  }
  checks.push(["example phase contract", contractOk]);
} else {
  console.log("note: examples/ absent (installed copy) — example checks skipped");
}

let failed = 0;
for (const [name, ok] of checks) { if (!ok) { console.log("FAIL " + name); failed++; } }
console.log(failed ? `${failed}/${checks.length} FAILED` : `ALL PASS ${checks.length}`);
process.exit(failed ? 1 : 0);
