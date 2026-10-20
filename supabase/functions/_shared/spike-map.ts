/**
 * Turns one Spike workout record into the arguments of `public.ingest_wearable_workout` (migration 0024).
 *
 * Written DEFENSIVELY (brief §16.5a): every field may be missing or the wrong type, and a strange field must never
 * lose the workout. Numbers that are not usable become null; the database range-checks again. The only reasons to
 * return null (skip the record) are that it is not a workout the app logs, or it has no usable id or start time.
 */

export type LogKind = 'run' | 'lift' | 'ride' | 'other';

export type IngestArgs = {
  p_provider_slug: string;
  p_external_id: string;
  p_activity_type: LogKind;
  p_title: string;
  p_started_at: string;
  p_duration_seconds: number | null;
  p_distance_m: number | null;
  p_calories: number | null;
  p_avg_hr: number | null;
  p_max_hr: number | null;
  p_cadence: number | null;
};

const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const rounded = (v: unknown): number | null => {
  const n = num(v);
  return n === null ? null : Math.round(n);
};

/** Spike's `workout_type` / `activity_type` slugs (docs: technical-references/activity_matrix) -> Run, Lift, Ride, Other. */
export function kindFor(type: unknown, tags: unknown): LogKind | null {
  const t = typeof type === 'string' ? type.toLowerCase() : '';
  const tagList = Array.isArray(tags) ? tags.map((x) => String(x).toLowerCase()) : [];
  // Things that are not workouts at all.
  if (t === 'sleep' || tagList.includes('sleep') || t.startsWith('sleep') || tagList.includes('mindfulness') && !tagList.includes('workout')) return null;
  if (t.includes('running') || t === 'run' || t === 'jogging') return 'run';
  if (t.includes('biking') || t.includes('cycling') || t === 'bmx' || t === 'handcycling') return 'ride';
  if (t === 'strength_training' || t === 'weight_lifting' || t === 'weightlifting' || t === 'powerlifting' || t === 'calisthenics' || t === 'functional_strength_training' || t === 'crossfit') return 'lift';
  return 'other';
}

function titleFor(kind: LogKind, name: unknown, startedAt: Date, offsetMinutes: number | null): string {
  if (typeof name === 'string' && name.trim()) return name.trim().slice(0, 80);
  const hour = new Date(startedAt.getTime() + (offsetMinutes ?? 0) * 60_000).getUTCHours();
  const word = hour >= 5 && hour < 12 ? 'Morning' : hour >= 12 && hour < 17 ? 'Afternoon' : hour >= 17 && hour < 21 ? 'Evening' : 'Night';
  return `${word} ${kind}`;
}

export function mapWorkout(w: unknown, fallbackProvider: string): IngestArgs | null {
  if (!w || typeof w !== 'object') return null;
  const r = w as Record<string, unknown>;
  const id = typeof r.record_id === 'string' && r.record_id ? r.record_id : null;
  const startRaw = typeof r.start_at_timestamp === 'string' ? r.start_at_timestamp : null;
  const start = startRaw ? new Date(startRaw) : null;
  if (!id || !start || Number.isNaN(start.getTime())) return null;

  const kind = kindFor(r.workout_type, r.workout_tags);
  if (kind === null) return null;

  const m = (r.metrics && typeof r.metrics === 'object' ? r.metrics : {}) as Record<string, unknown>;
  const endRaw = typeof r.end_at_timestamp === 'string' ? new Date(r.end_at_timestamp) : null;
  const fromTimestamps = endRaw && !Number.isNaN(endRaw.getTime()) ? Math.round((endRaw.getTime() - start.getTime()) / 1000) : null;
  // duration_active is in milliseconds. Start/end is preferred: the top-level `duration` has no documented unit.
  const activeMs = num(m.duration_active);
  const duration = fromTimestamps !== null && fromTimestamps > 0 ? fromTimestamps : activeMs !== null && activeMs > 0 ? Math.round(activeMs / 1000) : null;

  const distance = num(m.distance) ?? num(m.distance_running) ?? num(m.distance_cycling) ?? num(m.distance_walking);
  return {
    p_provider_slug: typeof r.provider_slug === 'string' && r.provider_slug ? r.provider_slug : fallbackProvider,
    p_external_id: id,
    p_activity_type: kind,
    p_title: titleFor(kind, r.workout_name, start, num(r.user_time_offset_minutes)),
    p_started_at: start.toISOString(),
    p_duration_seconds: duration,
    p_distance_m: distance !== null && distance > 0 ? distance : null,
    p_calories: rounded(m.calories_burned) ?? rounded(m.calories_burned_active),
    p_avg_hr: rounded(m.heartrate),
    p_max_hr: rounded(m.heartrate_max),
    p_cadence: rounded(m.cadence),
  };
}

export type SpikeEvent = {
  application_user_id?: string;
  event_type?: string;
  provider_slug?: string;
  earliest_record_start_at?: string;
  latest_record_end_at?: string;
};

/** The webhook body is an array of events — but be tolerant of a single object. */
export function parseEvents(raw: string): SpikeEvent[] {
  try {
    const parsed = JSON.parse(raw);
    const list = Array.isArray(parsed) ? parsed : [parsed];
    return list.filter((e) => e && typeof e === 'object') as SpikeEvent[];
  } catch {
    return [];
  }
}

/** The time window of workouts to re-read for a record_change, padded because a workout can start before its range. */
export function windowFor(e: SpikeEvent, now: Date = new Date()): { from: string; to: string } | null {
  const a = e.earliest_record_start_at ? new Date(e.earliest_record_start_at) : null;
  const b = e.latest_record_end_at ? new Date(e.latest_record_end_at) : null;
  if (!a || Number.isNaN(a.getTime())) return null;
  const end = b && !Number.isNaN(b.getTime()) ? b : now;
  const day = 24 * 3600 * 1000;
  // Cap the window so one odd event cannot trigger a huge read: the backfill window is the biggest legitimate one (30 days).
  const from = new Date(Math.max(a.getTime() - 3600 * 1000, now.getTime() - 31 * day));
  const to = new Date(Math.min(end.getTime() + 3600 * 1000, now.getTime() + day));
  return from < to ? { from: from.toISOString(), to: to.toISOString() } : null;
}
