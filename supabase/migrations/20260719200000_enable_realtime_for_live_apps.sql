do $$
declare
  table_name text;
  realtime_tables text[] := array[
    'profiles',
    'memberships',
    'churches',
    'church_subscriptions',
    'church_applications',
    'announcements',
    'events',
    'event_registrations',
    'donation_campaigns',
    'donations',
    'church_communications',
    'prayer_requests',
    'prayer_request_responses',
    'church_join_requests',
    'pastoral_requests',
    'administrative_requests',
    'ministry_join_requests',
    'volunteer_applications',
    'church_ministries',
    'ministry_members',
    'church_assets',
    'church_visitors',
    'church_expenses',
    'church_subscription_requests',
    'wallet_ledger_entries',
    'wallet_withdrawal_requests',
    'member_wallet_accounts',
    'member_wallet_ledger_entries',
    'pastoral_publications',
    'pastoral_publication_comments',
    'community_posts',
    'community_post_comments',
    'community_post_reactions',
    'community_post_saved',
    'community_post_reports',
    'community_member_warnings',
    'internal_notifications'
  ];
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    return;
  end if;

  foreach table_name in array realtime_tables loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format('alter table public.%I replica identity full', table_name);
      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = table_name
      ) then
        execute format(
          'alter publication supabase_realtime add table public.%I',
          table_name
        );
      end if;
    end if;
  end loop;
end $$;
