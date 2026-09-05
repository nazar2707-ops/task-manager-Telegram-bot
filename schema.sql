-- Telegram → ClickUp Task Agent — Postgres schema
-- Reconstructed from the workflow's queries. Compare with your original before applying.

CREATE TABLE IF NOT EXISTS tb_users (
  telegram_id      BIGINT PRIMARY KEY,
  display_name     TEXT NOT NULL,
  role             TEXT NOT NULL CHECK (role IN ('author', 'executor')),
  clickup_list_id  TEXT,                       -- authors only
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Every Telegram update, keyed by update_id → dedupe on webhook retries
CREATE TABLE IF NOT EXISTS tb_log (
  update_id    BIGINT PRIMARY KEY,
  telegram_id  BIGINT,
  payload      JSONB NOT NULL,
  received_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Message fragments per author, flushed on «готово»
CREATE TABLE IF NOT EXISTS tb_buffer (
  id           BIGSERIAL PRIMARY KEY,
  telegram_id  BIGINT NOT NULL REFERENCES tb_users(telegram_id),
  message_id   BIGINT NOT NULL,
  source       TEXT NOT NULL CHECK (source IN ('text', 'voice')),
  content      TEXT,
  has_media    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS tb_buffer_tg_idx ON tb_buffer (telegram_id, id);

-- One row per ClickUp task; executor_msg_id links the Telegram card
CREATE TABLE IF NOT EXISTS tb_tasks (
  id               BIGSERIAL PRIMARY KEY,
  clickup_task_id  TEXT NOT NULL,
  clickup_url      TEXT,
  author_tg_id     BIGINT NOT NULL REFERENCES tb_users(telegram_id),
  author_name      TEXT,
  title            TEXT NOT NULL,
  description      TEXT,
  priority         TEXT,
  due_date         DATE,
  hints            JSONB,
  batch_id         TEXT,
  status           TEXT NOT NULL DEFAULT 'todo',   -- todo | in_progress | done | waiting_answer | postponed
  executor_msg_id  BIGINT,                          -- Telegram message_id of the card
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS tb_tasks_exec_msg_idx ON tb_tasks (executor_msg_id);

-- Questions from executor to author, matched back by author_msg_id
CREATE TABLE IF NOT EXISTS tb_qa (
  id               BIGSERIAL PRIMARY KEY,
  task_id          BIGINT NOT NULL REFERENCES tb_tasks(id),
  question         TEXT NOT NULL,
  answer           TEXT,
  state            TEXT NOT NULL DEFAULT 'open',   -- open | answered
  executor_msg_id  BIGINT,                          -- executor's reply message
  author_msg_id    BIGINT,                          -- bot's question message in author chat
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  answered_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS tb_qa_author_msg_idx ON tb_qa (author_msg_id) WHERE state = 'open';

-- Seed users (replace with real Telegram IDs)
-- INSERT INTO tb_users VALUES
--   (111111111, 'Executor', 'executor', NULL),
--   (222222222, 'Author A', 'author', '<clickup_list_id_A>'),
--   (333333333, 'Author B', 'author', '<clickup_list_id_B>');
