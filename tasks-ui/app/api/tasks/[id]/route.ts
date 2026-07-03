import { NextRequest, NextResponse } from "next/server";
import { cancelTask, getTask, markDone, updateTask } from "@/lib/tasks-api";
import type { TaskUpdateFields } from "@/lib/tasks-api";

interface Ctx {
  params: Promise<{ id: string }>;
}

export async function GET(_req: NextRequest, { params }: Ctx) {
  const { id } = await params;
  const numericId = Number(id);
  if (!Number.isInteger(numericId) || numericId <= 0) {
    return NextResponse.json({ error: "invalid id" }, { status: 400 });
  }
  const task = await getTask(numericId);
  if (!task) return NextResponse.json({ error: "not found" }, { status: 404 });
  return NextResponse.json(task);
}

export async function PATCH(req: NextRequest, { params }: Ctx) {
  const { id } = await params;
  const numericId = Number(id);
  if (!Number.isInteger(numericId) || numericId <= 0) {
    return NextResponse.json({ error: "invalid id" }, { status: 400 });
  }
  try {
    const body = (await req.json()) as TaskUpdateFields & { notify?: boolean };
    const notify = body.notify !== false; // default true
    delete body.notify;
    if (Object.keys(body).length === 0) {
      return NextResponse.json({ error: "no fields to update" }, { status: 400 });
    }
    const task = await updateTask(numericId, body, notify);
    if (!task) return NextResponse.json({ error: "not found" }, { status: 404 });
    return NextResponse.json(task);
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: Ctx) {
  const { id } = await params;
  const numericId = Number(id);
  if (!Number.isInteger(numericId) || numericId <= 0) {
    return NextResponse.json({ error: "invalid id" }, { status: 400 });
  }
  const notify = req.nextUrl.searchParams.get("notify") !== "false";
  try {
    const task = await cancelTask(numericId, notify);
    if (!task) return NextResponse.json({ error: "not found" }, { status: 404 });
    return NextResponse.json(task);
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

// POST /api/tasks/<id>/done — semantically distinct verb, exposed as a POST
// on this route via ?action=done for simplicity.
export async function POST(req: NextRequest, { params }: Ctx) {
  const { id } = await params;
  const numericId = Number(id);
  if (!Number.isInteger(numericId) || numericId <= 0) {
    return NextResponse.json({ error: "invalid id" }, { status: 400 });
  }
  const action = req.nextUrl.searchParams.get("action");
  const notify = req.nextUrl.searchParams.get("notify") !== "false";
  if (action === "done") {
    const task = await markDone(numericId, notify);
    if (!task) return NextResponse.json({ error: "not found" }, { status: 404 });
    return NextResponse.json(task);
  }
  return NextResponse.json({ error: "unknown action" }, { status: 400 });
}
