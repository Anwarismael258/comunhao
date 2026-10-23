import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  try {
    const auth = request.headers.get('Authorization');
    const url = Deno.env.get('SUPABASE_URL') ?? '';
    const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const hqUrl = Deno.env.get('HQ_FILE_REGISTRY_URL') ?? '';
    const hqToken = Deno.env.get('HQ_FILE_REGISTRY_TOKEN') ?? '';
    if (!auth || !url || !anon || !service || !hqUrl || !hqToken) return json({ error: 'INTEGRATION_NOT_CONFIGURED' }, 503);
    const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const admin = createClient(url, service);
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: 'INVALID_SESSION' }, 401);
    const body = await request.json();
    const churchId = String(body.church_id || '');
    const path = String(body.path || '');
    const documentId = String(body.document_id || '');
    if (!churchId || !path || !documentId || /^https?:/i.test(path)) return json({ error: 'INVALID_FILE_REFERENCE' }, 400);
    const { data: membership } = await admin.from('memberships').select('church_id,role,status').eq('profile_id', userData.user.id).eq('church_id', churchId).eq('status', 'active').in('role', ['pastor', 'church_admin', 'secretary']).maybeSingle();
    if (!membership) return json({ error: 'CHURCH_ACCESS_DENIED' }, 403);
    const { data: document } = await admin.from('church_documents').select('id,title,document_type,confidentiality,church_id').eq('id', documentId).eq('church_id', churchId).maybeSingle();
    if (!document) return json({ error: 'DOCUMENT_NOT_FOUND' }, 404);
    const { data: signed, error: storageError } = await admin.storage.from('church-documents').createSignedUrl(path, 60);
    if (storageError || !signed?.signedUrl) return json({ error: 'STORAGE_OBJECT_NOT_FOUND' }, 404);
    const response = await fetch(hqUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-hq-file-registry-token': hqToken },
      body: JSON.stringify({
        platform: 'comunhao', source_system: 'comunhao', source_bucket: 'church-documents', source_path: path,
        subject_type: 'church', subject_id: churchId, category: 'church',
        classification: document.confidentiality === 'public' ? 'operational' : 'confidential',
        file_name: document.title, metadata: { church_document_id: document.id, document_type: document.document_type },
      }),
    });
    if (!response.ok) return json({ error: 'HQ_REGISTRY_FAILED' }, 502);
    return json({ ok: true });
  } catch (cause) {
    return json({ error: cause instanceof Error ? cause.message : 'INTERNAL_ERROR' }, 500);
  }
});
