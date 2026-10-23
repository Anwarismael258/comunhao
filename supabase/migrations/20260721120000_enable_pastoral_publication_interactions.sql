update public.pastoral_publications
set
  allow_comments = true,
  allow_reactions = true,
  allow_sharing = true
where status = 'published';
