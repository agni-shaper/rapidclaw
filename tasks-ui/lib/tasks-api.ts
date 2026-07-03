import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { Task, TaskFilters, TaskStatus, TaskPriority } from "./types";

const execFileP = promisify(execFile);

// Absolute path — the Next.js server runs from tasks-ui/, but tasks.sh
// lives in the parent repo's accountability/routines/.
const TASKS_SH = "/Users/agni/Documents/rapidclaw/accountability/routines/tasks.sh";

async function run(args: string[]): Promise<string> {
  try {
    const { stdout } = await execFileP(TASKS_SH, args, {
      maxBuffer: 20 * 1024 * 1024, // 20 MB — enough for large `list --json`
    });
    return stdout;
  } catch (err) {
    const e = err as { stderr?: string; stdout?: string; code?: number; message?: string };
    const msg = e.stderr?.trim() || e.stdout?.trim() || e.message || "unknown tasks.sh error";
    throw new Error(`tasks.sh ${args.join(" ")} failed (exit ${e.code ?? "?"}): ${msg}`);
  }
}

export async function listTasks(filters: TaskFilters = {}): Promise<Task[]> {
  // Always fetch --all so the client can group/filter — API-side filtering
  // is used only for scoped queries (e.g. /api/tasks?assignee=@X).
  const args = ["list", "--all", "--json"];
  if (filters.assignee) args.push("--assignee", filters.assignee);
  if (filters.status && !filters.all) args.push("--status", filters.status);
  if (filters.priority) args.push("--priority", filters.priority);
  if (filters.category) args.push("--category", filters.category);
  if (filters.product) args.push("--product", filters.product);
  if (filters.overdue) args.push("--overdue");

  const stdout = await run(args);
  const trimmed = stdout.trim();
  if (!trimmed || trimmed === "[]" || trimmed === "(no tasks match)") return [];
  const raw = JSON.parse(trimmed);
  return Array.isArray(raw) ? (raw as Task[]) : [];
}

export async function getTask(id: number): Promise<Task | null> {
  try {
    const stdout = await run(["get", String(id), "--json"]);
    if (!stdout.trim()) return null;
    return JSON.parse(stdout) as Task;
  } catch {
    return null;
  }
}

export interface CreateTaskInput {
  assignee: string; // @handle OR Slack ID
  due_date: string; // YYYY-MM-DD
  title: string;
  priority?: TaskPriority;
  category?: string;
  product?: string;
  source?: string;
  description?: string;
  notify?: boolean;
  force?: boolean;
}

export async function createTask(input: CreateTaskInput): Promise<Task> {
  const args = ["add", input.assignee, input.due_date, input.title];
  if (input.priority) args.push("--priority", input.priority);
  if (input.category) args.push("--category", input.category);
  if (input.product) args.push("--product", input.product);
  if (input.source) args.push("--source", input.source);
  if (input.description) args.push("--description", input.description);
  if (input.force) args.push("--force");
  args.push("--notify", "--json");

  const stdout = await run(args);
  return JSON.parse(stdout) as Task;
}

export type TaskUpdateFields = Partial<
  Pick<
    Task,
    "title" | "description" | "assignee" | "status" | "priority" | "category" | "product" | "due_date" | "source"
  >
>;

export async function updateTask(id: number, fields: TaskUpdateFields, notify = true): Promise<Task | null> {
  const args = ["update", String(id)];
  for (const [k, v] of Object.entries(fields)) {
    if (v === undefined || v === null) continue;
    args.push(`${k}=${v}`);
  }
  if (notify) args.push("--notify");
  args.push("--json");
  const stdout = await run(args);
  if (!stdout.trim()) return await getTask(id);
  try {
    return JSON.parse(stdout) as Task;
  } catch {
    return await getTask(id);
  }
}

export async function markDone(id: number, notify = true): Promise<Task | null> {
  const args = ["done", String(id)];
  if (notify) args.push("--notify");
  await run(args);
  return await getTask(id);
}

export async function cancelTask(id: number, notify = true): Promise<Task | null> {
  const args = ["rm", String(id)];
  if (notify) args.push("--notify");
  await run(args);
  return await getTask(id);
}

export function updateStatus(id: number, status: TaskStatus) {
  return updateTask(id, { status });
}
