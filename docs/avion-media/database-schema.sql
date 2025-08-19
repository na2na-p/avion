-- avion-media PostgreSQL Database Schema
-- メディア管理サービス用データベーススキーマ定義

-- ================================================================
-- メディアメタデータテーブル
-- メディアファイルの詳細情報を格納
-- ================================================================
CREATE TABLE IF NOT EXISTS media_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL UNIQUE,
    width INTEGER CHECK (width > 0),
    height INTEGER CHECK (height > 0),
    duration INTEGER CHECK (duration >= 0), -- 動画・音声の長さ（秒）
    format VARCHAR(50) NOT NULL,
    color_palette JSONB, -- 主要な色情報
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- インデックス
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) 
        REFERENCES media(id) ON DELETE CASCADE
);

-- パフォーマンス向上のためのインデックス
CREATE INDEX idx_media_metadata_media_id ON media_metadata(media_id);
CREATE INDEX idx_media_metadata_format ON media_metadata(format);
CREATE INDEX idx_media_metadata_created_at ON media_metadata(created_at DESC);

-- 更新時刻自動更新トリガー
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_media_metadata_updated_at 
    BEFORE UPDATE ON media_metadata 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- メディアテーブル（既存テーブルの拡張）
-- 基本的なメディア情報を格納
-- ================================================================
CREATE TABLE IF NOT EXISTS media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    storage_key VARCHAR(500) NOT NULL UNIQUE,
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL CHECK (file_size > 0),
    mime_type VARCHAR(100) NOT NULL,
    media_type VARCHAR(50) NOT NULL CHECK (media_type IN ('IMAGE', 'VIDEO', 'AUDIO', 'DOCUMENT')),
    upload_status VARCHAR(50) NOT NULL DEFAULT 'PENDING' 
        CHECK (upload_status IN ('PENDING', 'UPLOADING', 'COMPLETED', 'FAILED')),
    processing_status VARCHAR(50) NOT NULL DEFAULT 'QUEUED'
        CHECK (processing_status IN ('QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED', 'SKIPPED')),
    nsfw_flag BOOLEAN DEFAULT FALSE,
    alt_text TEXT CHECK (length(alt_text) <= 1500),
    usage_count INTEGER DEFAULT 0 CHECK (usage_count >= 0),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- インデックス
    CONSTRAINT fk_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE CASCADE
);

-- パフォーマンス最適化のためのインデックス
CREATE INDEX idx_media_user_id ON media(user_id);
CREATE INDEX idx_media_media_type ON media(media_type);
CREATE INDEX idx_media_upload_status ON media(upload_status);
CREATE INDEX idx_media_processing_status ON media(processing_status);
CREATE INDEX idx_media_created_at ON media(created_at DESC);
CREATE INDEX idx_media_is_deleted ON media(is_deleted) WHERE is_deleted = FALSE;
CREATE INDEX idx_media_nsfw_flag ON media(nsfw_flag) WHERE nsfw_flag = TRUE;

-- ================================================================
-- サムネイルテーブル
-- 生成されたサムネイル情報を管理
-- ================================================================
CREATE TABLE IF NOT EXISTS thumbnails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL,
    size VARCHAR(20) NOT NULL CHECK (size IN ('small', 'medium', 'large')),
    width INTEGER NOT NULL CHECK (width > 0),
    height INTEGER NOT NULL CHECK (height > 0),
    storage_key VARCHAR(500) NOT NULL UNIQUE,
    file_size BIGINT NOT NULL CHECK (file_size > 0),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 複合ユニーク制約（同一メディアの同一サイズは1つのみ）
    CONSTRAINT unique_media_size UNIQUE (media_id, size),
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) 
        REFERENCES media(id) ON DELETE CASCADE
);

CREATE INDEX idx_thumbnails_media_id ON thumbnails(media_id);
CREATE INDEX idx_thumbnails_size ON thumbnails(size);

-- ================================================================
-- メディア処理タスクテーブル
-- 非同期処理タスクの管理
-- ================================================================
CREATE TABLE IF NOT EXISTS media_processing_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL,
    task_type VARCHAR(50) NOT NULL 
        CHECK (task_type IN ('thumbnail_generation', 'video_transcoding', 
                            'audio_transcoding', 'remote_cache', 'deletion')),
    task_status VARCHAR(50) NOT NULL DEFAULT 'SCHEDULED'
        CHECK (task_status IN ('SCHEDULED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    parameters JSONB,
    retry_count INTEGER DEFAULT 0 CHECK (retry_count >= 0 AND retry_count <= 5),
    scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) 
        REFERENCES media(id) ON DELETE CASCADE
);

CREATE INDEX idx_processing_tasks_media_id ON media_processing_tasks(media_id);
CREATE INDEX idx_processing_tasks_status ON media_processing_tasks(task_status);
CREATE INDEX idx_processing_tasks_type ON media_processing_tasks(task_type);
CREATE INDEX idx_processing_tasks_scheduled ON media_processing_tasks(scheduled_at) 
    WHERE task_status = 'SCHEDULED';

-- ================================================================
-- ストレージ使用量管理テーブル
-- ユーザー別のストレージ使用量を追跡
-- ================================================================
CREATE TABLE IF NOT EXISTS storage_quotas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    quota_limit BIGINT NOT NULL DEFAULT 5368709120, -- 5GB デフォルト
    used_space BIGINT NOT NULL DEFAULT 0 CHECK (used_space >= 0),
    media_count INTEGER DEFAULT 0 CHECK (media_count >= 0),
    last_calculated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT check_quota CHECK (used_space <= quota_limit)
);

CREATE INDEX idx_storage_quotas_user_id ON storage_quotas(user_id);
CREATE INDEX idx_storage_quotas_usage ON storage_quotas(used_space DESC);

-- ================================================================
-- リモートメディアキャッシュテーブル
-- ActivityPub等の外部メディアのキャッシュ管理
-- ================================================================
CREATE TABLE IF NOT EXISTS remote_media_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    remote_url TEXT NOT NULL UNIQUE,
    cache_key VARCHAR(64) NOT NULL UNIQUE, -- SHA-256 hash of URL
    local_media_id UUID,
    cache_status VARCHAR(50) NOT NULL DEFAULT 'PENDING'
        CHECK (cache_status IN ('PENDING', 'CACHED', 'FAILED', 'EXPIRED')),
    fetched_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    access_count INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_local_media_id FOREIGN KEY (local_media_id) 
        REFERENCES media(id) ON DELETE SET NULL
);

CREATE INDEX idx_remote_cache_url_hash ON remote_media_cache(cache_key);
CREATE INDEX idx_remote_cache_status ON remote_media_cache(cache_status);
CREATE INDEX idx_remote_cache_expires ON remote_media_cache(expires_at) 
    WHERE cache_status = 'CACHED';
CREATE INDEX idx_remote_cache_last_accessed ON remote_media_cache(last_accessed_at DESC);

-- ================================================================
-- メディアアルバムテーブル
-- ユーザーが作成するメディアコレクション
-- ================================================================
CREATE TABLE IF NOT EXISTS media_albums (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    visibility VARCHAR(20) NOT NULL DEFAULT 'PRIVATE'
        CHECK (visibility IN ('PUBLIC', 'PRIVATE', 'LIMITED')),
    share_token UUID UNIQUE,
    media_count INTEGER DEFAULT 0 CHECK (media_count >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_albums_user_id ON media_albums(user_id);
CREATE INDEX idx_albums_visibility ON media_albums(visibility);
CREATE INDEX idx_albums_share_token ON media_albums(share_token) WHERE share_token IS NOT NULL;

-- ================================================================
-- アルバムメディア関連テーブル
-- アルバムとメディアの多対多関係
-- ================================================================
CREATE TABLE IF NOT EXISTS album_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    album_id UUID NOT NULL,
    media_id UUID NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    caption TEXT CHECK (length(caption) <= 500),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 複合ユニーク制約
    CONSTRAINT unique_album_media UNIQUE (album_id, media_id),
    CONSTRAINT fk_album_id FOREIGN KEY (album_id) 
        REFERENCES media_albums(id) ON DELETE CASCADE,
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) 
        REFERENCES media(id) ON DELETE CASCADE
);

CREATE INDEX idx_album_media_album ON album_media(album_id);
CREATE INDEX idx_album_media_media ON album_media(media_id);
CREATE INDEX idx_album_media_position ON album_media(album_id, position);

-- ================================================================
-- メディアタグテーブル
-- メディアの分類用タグ
-- ================================================================
CREATE TABLE IF NOT EXISTS media_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    tag_name VARCHAR(50) NOT NULL,
    usage_count INTEGER DEFAULT 0 CHECK (usage_count >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- ユーザー内でタグ名は一意
    CONSTRAINT unique_user_tag UNIQUE (user_id, tag_name),
    CONSTRAINT fk_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_tags_user_id ON media_tags(user_id);
CREATE INDEX idx_tags_name ON media_tags(tag_name);
CREATE INDEX idx_tags_usage ON media_tags(usage_count DESC);

-- ================================================================
-- メディアタグ関連テーブル
-- メディアとタグの多対多関係
-- ================================================================
CREATE TABLE IF NOT EXISTS media_tag_relations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL,
    tag_id UUID NOT NULL,
    tagged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 複合ユニーク制約
    CONSTRAINT unique_media_tag UNIQUE (media_id, tag_id),
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) 
        REFERENCES media(id) ON DELETE CASCADE,
    CONSTRAINT fk_tag_id FOREIGN KEY (tag_id) 
        REFERENCES media_tags(id) ON DELETE CASCADE
);

CREATE INDEX idx_media_tag_media ON media_tag_relations(media_id);
CREATE INDEX idx_media_tag_tag ON media_tag_relations(tag_id);

-- ================================================================
-- アクセシビリティメタデータテーブル
-- アクセシビリティ向上のための補助情報
-- ================================================================
CREATE TABLE IF NOT EXISTS accessibility_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL UNIQUE,
    alt_text TEXT CHECK (length(alt_text) <= 1500),
    audio_description_url TEXT,
    contrast_mode VARCHAR(20) CHECK (contrast_mode IN ('NORMAL', 'HIGH', 'AUTO')),
    screen_reader_optimized BOOLEAN DEFAULT FALSE,
    generated_by_ai BOOLEAN DEFAULT FALSE,
    ai_confidence_score DECIMAL(3, 2) CHECK (ai_confidence_score >= 0 AND ai_confidence_score <= 1),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) 
        REFERENCES media(id) ON DELETE CASCADE
);

CREATE INDEX idx_accessibility_media_id ON accessibility_metadata(media_id);
CREATE INDEX idx_accessibility_ai_generated ON accessibility_metadata(generated_by_ai) 
    WHERE generated_by_ai = TRUE;

-- ================================================================
-- メディア使用統計テーブル
-- メディアの使用状況を追跡
-- ================================================================
CREATE TABLE IF NOT EXISTS media_usage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL,
    date DATE NOT NULL,
    view_count INTEGER DEFAULT 0 CHECK (view_count >= 0),
    download_count INTEGER DEFAULT 0 CHECK (download_count >= 0),
    bandwidth_bytes BIGINT DEFAULT 0 CHECK (bandwidth_bytes >= 0),
    unique_viewers INTEGER DEFAULT 0 CHECK (unique_viewers >= 0),
    
    -- 日付ごとに1レコード
    CONSTRAINT unique_media_date UNIQUE (media_id, date),
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) 
        REFERENCES media(id) ON DELETE CASCADE
);

CREATE INDEX idx_usage_stats_media ON media_usage_stats(media_id);
CREATE INDEX idx_usage_stats_date ON media_usage_stats(date DESC);
CREATE INDEX idx_usage_stats_views ON media_usage_stats(view_count DESC);

-- ================================================================
-- ストレージ成長追跡テーブル
-- ストレージ使用量の時系列変化を記録
-- ================================================================
CREATE TABLE IF NOT EXISTS storage_growth_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    total_storage_bytes BIGINT NOT NULL CHECK (total_storage_bytes >= 0),
    total_media_count INTEGER NOT NULL CHECK (total_media_count >= 0),
    active_user_count INTEGER NOT NULL CHECK (active_user_count >= 0),
    average_file_size BIGINT CHECK (average_file_size >= 0),
    growth_rate_daily DECIMAL(5, 2), -- パーセント
    growth_rate_monthly DECIMAL(5, 2), -- パーセント
    projected_storage_30d BIGINT, -- 30日後の予測値
    projected_storage_90d BIGINT, -- 90日後の予測値
    storage_tier_distribution JSONB -- 各階層の使用量分布
);

CREATE INDEX idx_growth_tracking_date ON storage_growth_tracking(recorded_at DESC);

-- ================================================================
-- CDNキャッシュ統計テーブル
-- CDNのキャッシュヒット率とパフォーマンスを追跡
-- ================================================================
CREATE TABLE IF NOT EXISTS cdn_cache_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    cache_hit_count BIGINT DEFAULT 0 CHECK (cache_hit_count >= 0),
    cache_miss_count BIGINT DEFAULT 0 CHECK (cache_miss_count >= 0),
    cache_hit_rate DECIMAL(5, 2) CHECK (cache_hit_rate >= 0 AND cache_hit_rate <= 100),
    bandwidth_saved_bytes BIGINT DEFAULT 0 CHECK (bandwidth_saved_bytes >= 0),
    average_response_time_ms INTEGER CHECK (average_response_time_ms >= 0),
    p50_latency_ms INTEGER CHECK (p50_latency_ms >= 0),
    p95_latency_ms INTEGER CHECK (p95_latency_ms >= 0),
    p99_latency_ms INTEGER CHECK (p99_latency_ms >= 0),
    edge_locations JSONB -- エッジロケーション別の統計
);

CREATE INDEX idx_cdn_stats_date ON cdn_cache_stats(recorded_at DESC);
CREATE INDEX idx_cdn_stats_hit_rate ON cdn_cache_stats(cache_hit_rate DESC);

-- ================================================================
-- ビュー定義
-- よく使用するクエリを最適化
-- ================================================================

-- アクティブメディア概要ビュー
CREATE OR REPLACE VIEW active_media_overview AS
SELECT 
    m.id,
    m.user_id,
    m.file_name,
    m.media_type,
    m.file_size,
    m.nsfw_flag,
    m.usage_count,
    mm.width,
    mm.height,
    mm.duration,
    mm.format,
    m.created_at
FROM media m
LEFT JOIN media_metadata mm ON m.id = mm.media_id
WHERE m.is_deleted = FALSE
    AND m.upload_status = 'COMPLETED'
    AND m.processing_status = 'COMPLETED';

-- ユーザーストレージ使用状況ビュー
CREATE OR REPLACE VIEW user_storage_summary AS
SELECT 
    sq.user_id,
    sq.quota_limit,
    sq.used_space,
    sq.media_count,
    ROUND((sq.used_space::DECIMAL / sq.quota_limit) * 100, 2) AS usage_percentage,
    (sq.quota_limit - sq.used_space) AS available_space,
    sq.last_calculated_at
FROM storage_quotas sq;

-- 日次メディア統計ビュー
CREATE OR REPLACE VIEW daily_media_statistics AS
SELECT 
    date,
    SUM(view_count) AS total_views,
    SUM(download_count) AS total_downloads,
    SUM(bandwidth_bytes) AS total_bandwidth,
    AVG(unique_viewers) AS avg_unique_viewers,
    COUNT(DISTINCT media_id) AS active_media_count
FROM media_usage_stats
GROUP BY date
ORDER BY date DESC;

-- ================================================================
-- 関数定義
-- ビジネスロジックの実装
-- ================================================================

-- ストレージ使用量再計算関数
CREATE OR REPLACE FUNCTION recalculate_user_storage(p_user_id UUID)
RETURNS TABLE(used_space BIGINT, media_count INTEGER) AS $$
BEGIN
    RETURN QUERY
    UPDATE storage_quotas sq
    SET 
        used_space = COALESCE(calc.total_size, 0),
        media_count = COALESCE(calc.count, 0),
        last_calculated_at = CURRENT_TIMESTAMP
    FROM (
        SELECT 
            SUM(file_size) AS total_size,
            COUNT(*) AS count
        FROM media
        WHERE user_id = p_user_id
            AND is_deleted = FALSE
    ) calc
    WHERE sq.user_id = p_user_id
    RETURNING sq.used_space, sq.media_count;
END;
$$ LANGUAGE plpgsql;

-- メディア削除時のクリーンアップ関数
CREATE OR REPLACE FUNCTION cleanup_deleted_media()
RETURNS void AS $$
BEGIN
    -- 7日以上前に削除マークされたメディアを物理削除
    DELETE FROM media
    WHERE is_deleted = TRUE
        AND deleted_at < CURRENT_TIMESTAMP - INTERVAL '7 days';
    
    -- 90日間アクセスされていないリモートキャッシュを削除
    UPDATE remote_media_cache
    SET cache_status = 'EXPIRED'
    WHERE cache_status = 'CACHED'
        AND last_accessed_at < CURRENT_TIMESTAMP - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- 初期データ
-- システム起動時に必要な基本データ
-- ================================================================

-- デフォルトのメディアタイプ設定（将来の拡張用）
-- ※実際の初期データは別途マイグレーションスクリプトで管理

-- ================================================================
-- 権限設定
-- アプリケーションユーザーの権限
-- ================================================================

-- アプリケーションユーザーへの権限付与（例）
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO avion_media_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO avion_media_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO avion_media_app;