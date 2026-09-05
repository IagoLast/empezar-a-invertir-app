import { endpoint, body, requireInput } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
export const POST = endpoint('POST', async request => {
  const { authorization } = await authenticated(request);
  const b = await body(request);
  requireInput(typeof b.lessonId === 'string' && /^lesson-[1-4]$/.test(b.lessonId));
  return rpc('complete_lesson', { p_lesson: b.lessonId }, authorization);
});
