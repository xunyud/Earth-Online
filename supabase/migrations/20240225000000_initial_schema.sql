-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- RawMessage Table
create table if not exists raw_messages (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null,
  content text not null,
  received_at timestamptz default now()
);

-- ParsedTask Table (Legacy, kept for reference or migration)
create table if not exists parsed_tasks (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null,
  title text not null,
  original_context text[] default '{}',
  start_time timestamptz,
  duration_minutes int,
  priority text check (priority in ('low', 'medium', 'high')),
  dependencies text[] default '{}',
  status text check (status in ('pending', 'in_progress', 'done')) default 'pending',
  created_at timestamptz default now()
);

-- Quest Nodes Table (The main table for Quest Log)
create table if not exists quest_nodes (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null,
  parent_id uuid references quest_nodes(id), -- Hierarchical link
  title text not null,
  quest_tier text check (quest_tier in ('Main_Quest', 'Side_Quest', 'Daily')),
  original_context text[] default '{}',
  is_completed boolean default false,
  xp_reward int default 0,
  created_at timestamptz default now()
);

-- Create index for performance
create index if not exists idx_quest_nodes_user_parent on quest_nodes(user_id, parent_id);

-- Profiles Table (extends auth.users)
create table if not exists profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  wechat_openid text unique,
  binding_code text,
  binding_expires_at timestamptz,
  created_at timestamptz default now()
);

-- Enable Row Level Security
alter table profiles enable row level security;

-- Policy: Users can view their own profile
create policy "Users can view own profile" on profiles
  for select using (auth.uid() = id);

-- Policy: Users can update their own profile (e.g., binding code)
create policy "Users can update own profile" on profiles
  for update using (auth.uid() = id);

-- Function to handle new user creation
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

-- Trigger for new user creation
create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
