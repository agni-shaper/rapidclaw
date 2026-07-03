import { NextResponse } from "next/server";
import { loadRoster } from "@/lib/roster-server";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET() {
  try {
    const roster = await loadRoster();
    return NextResponse.json(roster);
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}
