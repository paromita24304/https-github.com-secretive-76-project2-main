/*
# Create enrollments, quiz_results, achievements, user_stats tables for student portal

1. New Tables

- `enrollments`: Tracks which courses a student is enrolled in.
  - `id` (uuid, primary key)
  - `user_id` (uuid, not null, defaults to authenticated user, references auth.users)
  - `course_slug` (text, not null — matches the course slug from mock data)
  - `status` (text, not null, default 'active' — 'active' | 'completed')
  - `progress` (integer, default 0 — percentage 0-100)
  - `enrolled_at` (timestamp, default now)
  - `completed_at` (timestamp, nullable)
  - `created_at` (timestamp, default now)
  - `updated_at` (timestamp, default now, auto-updated via trigger)
  - Unique constraint on (user_id, course_slug)

- `quiz_results`: Stores quiz attempt results for tracking and achievements.
  - `id` (uuid, primary key)
  - `user_id` (uuid, not null, defaults to authenticated user, references auth.users)
  - `quiz_id` (text, not null — matches quiz id from practice data)
  - `quiz_title` (text, not null)
  - `score` (integer, not null — percentage 0-100)
  - `total_questions` (integer, not null)
  - `correct_answers` (integer, not null)
  - `passed` (boolean, not null, default false — true if score >= 80)
  - `attempted_at` (timestamp, default now)
  - `created_at` (timestamp, default now)

- `user_achievements`: Tracks which achievements a student has unlocked.
  - `id` (uuid, primary key)
  - `user_id` (uuid, not null, defaults to authenticated user, references auth.users)
  - `achievement_id` (text, not null — matches achievement id from practice data)
  - `unlocked_at` (timestamp, default now)
  - Unique constraint on (user_id, achievement_id)

- `user_stats`: Aggregated learning stats per user (streak, hours, skill points, etc.).
  - `id` (uuid, primary key)
  - `user_id` (uuid, not null, defaults to authenticated user, references auth.users, unique)
  - `courses_completed` (integer, default 0)
  - `hours_learned` (integer, default 0)
  - `current_streak` (integer, default 0)
  - `skill_points` (integer, default 0)
  - `quizzes_passed` (integer, default 0)
  - `labs_completed` (integer, default 0)
  - `last_active_date` (date, nullable — used for streak calculation)
  - `created_at` (timestamp, default now)
  - `updated_at` (timestamp, default now, auto-updated via trigger)

- `lab_progress`: Tracks lab completion (labs are lessons of type 'lab' inside courses).
  - `id` (uuid, primary key)
  - `user_id` (uuid, not null, defaults to authenticated user, references auth.users)
  - `course_id` (text, not null)
  - `lesson_id` (text, not null — the lab lesson id)
  - `status` (text, not null, default 'not-started' — 'not-started' | 'in-progress' | 'completed')
  - `completed_at` (timestamp, nullable)
  - `created_at` (timestamp, default now)
  - `updated_at` (timestamp, default now, auto-updated via trigger)
  - Unique constraint on (user_id, lesson_id)

2. Indexes
  - enrollments: user_id, user_id+course_slug
  - quiz_results: user_id, user_id+quiz_id
  - user_achievements: user_id, user_id+achievement_id
  - user_stats: user_id (unique)
  - lab_progress: user_id, user_id+lesson_id

3. Security
  - RLS enabled on all tables with owner-scoped CRUD (4 policies each, auth.uid() = user_id).
  - user_id defaults to auth.uid() so inserts that omit user_id satisfy WITH CHECK.
  - updated_at auto-set via existing set_updated_at() trigger function.

4. Notes
  - course_slug, quiz_id, achievement_id, lesson_id, course_id are text (not FKs) because
    courses/quizzes/achievements currently come from client-side data.
  - All tables are idempotent (IF NOT EXISTS, DROP POLICY IF EXISTS before CREATE POLICY).
*/

-- =============================================================
-- enrollments
-- =============================================================
CREATE TABLE IF NOT EXISTS enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  course_slug text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  progress integer NOT NULL DEFAULT 0,
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, course_slug)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_user ON enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_user_course ON enrollments(user_id, course_slug);

ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_enrollments" ON enrollments;
CREATE POLICY "select_own_enrollments" ON enrollments FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_enrollments" ON enrollments;
CREATE POLICY "insert_own_enrollments" ON enrollments FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_enrollments" ON enrollments;
CREATE POLICY "update_own_enrollments" ON enrollments FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_enrollments" ON enrollments;
CREATE POLICY "delete_own_enrollments" ON enrollments FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS trg_enrollments_updated ON enrollments;
CREATE TRIGGER trg_enrollments_updated
BEFORE UPDATE ON enrollments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================
-- quiz_results
-- =============================================================
CREATE TABLE IF NOT EXISTS quiz_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  quiz_id text NOT NULL,
  quiz_title text NOT NULL,
  score integer NOT NULL,
  total_questions integer NOT NULL,
  correct_answers integer NOT NULL,
  passed boolean NOT NULL DEFAULT false,
  attempted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_quiz_results_user ON quiz_results(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_results_user_quiz ON quiz_results(user_id, quiz_id);

ALTER TABLE quiz_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_quiz_results" ON quiz_results;
CREATE POLICY "select_own_quiz_results" ON quiz_results FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_quiz_results" ON quiz_results;
CREATE POLICY "insert_own_quiz_results" ON quiz_results FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_quiz_results" ON quiz_results;
CREATE POLICY "update_own_quiz_results" ON quiz_results FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_quiz_results" ON quiz_results;
CREATE POLICY "delete_own_quiz_results" ON quiz_results FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- =============================================================
-- user_achievements
-- =============================================================
CREATE TABLE IF NOT EXISTS user_achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id text NOT NULL,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_ach ON user_achievements(user_id, achievement_id);

ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_user_achievements" ON user_achievements;
CREATE POLICY "select_own_user_achievements" ON user_achievements FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_user_achievements" ON user_achievements;
CREATE POLICY "insert_own_user_achievements" ON user_achievements FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_user_achievements" ON user_achievements;
CREATE POLICY "update_own_user_achievements" ON user_achievements FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_user_achievements" ON user_achievements;
CREATE POLICY "delete_own_user_achievements" ON user_achievements FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- =============================================================
-- user_stats
-- =============================================================
CREATE TABLE IF NOT EXISTS user_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  courses_completed integer NOT NULL DEFAULT 0,
  hours_learned integer NOT NULL DEFAULT 0,
  current_streak integer NOT NULL DEFAULT 0,
  skill_points integer NOT NULL DEFAULT 0,
  quizzes_passed integer NOT NULL DEFAULT 0,
  labs_completed integer NOT NULL DEFAULT 0,
  last_active_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_stats_user ON user_stats(user_id);

ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_user_stats" ON user_stats;
CREATE POLICY "select_own_user_stats" ON user_stats FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_user_stats" ON user_stats;
CREATE POLICY "insert_own_user_stats" ON user_stats FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_user_stats" ON user_stats;
CREATE POLICY "update_own_user_stats" ON user_stats FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_user_stats" ON user_stats;
CREATE POLICY "delete_own_user_stats" ON user_stats FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS trg_user_stats_updated ON user_stats;
CREATE TRIGGER trg_user_stats_updated
BEFORE UPDATE ON user_stats
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================
-- lab_progress
-- =============================================================
CREATE TABLE IF NOT EXISTS lab_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id text NOT NULL,
  lesson_id text NOT NULL,
  status text NOT NULL DEFAULT 'not-started',
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, lesson_id)
);

CREATE INDEX IF NOT EXISTS idx_lab_progress_user ON lab_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_lab_progress_user_lesson ON lab_progress(user_id, lesson_id);

ALTER TABLE lab_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_lab_progress" ON lab_progress;
CREATE POLICY "select_own_lab_progress" ON lab_progress FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_lab_progress" ON lab_progress;
CREATE POLICY "insert_own_lab_progress" ON lab_progress FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_lab_progress" ON lab_progress;
CREATE POLICY "update_own_lab_progress" ON lab_progress FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_lab_progress" ON lab_progress;
CREATE POLICY "delete_own_lab_progress" ON lab_progress FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS trg_lab_progress_updated ON lab_progress;
CREATE TRIGGER trg_lab_progress_updated
BEFORE UPDATE ON lab_progress
FOR EACH ROW EXECUTE FUNCTION set_updated_at();