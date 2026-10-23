do $$
declare
  existing_secret_id uuid;
begin
  select id
  into existing_secret_id
  from vault.decrypted_secrets
  where name = 'mozesms_sender_id'
  order by updated_at desc
  limit 1;

  if existing_secret_id is null then
    perform vault.create_secret(
      'ESHOP',
      'mozesms_sender_id',
      'Approved MozeSMS sender id for Comunhao',
      null
    );
  else
    perform vault.update_secret(
      existing_secret_id,
      'ESHOP',
      'mozesms_sender_id',
      'Approved MozeSMS sender id for Comunhao',
      null
    );
  end if;
end;
$$;
