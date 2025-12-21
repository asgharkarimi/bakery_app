-- =============================================
-- Database Schema for Bakery Job App
-- MySQL / MariaDB
-- =============================================

-- جدول کاربران
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    phone VARCHAR(11) NOT NULL UNIQUE,
    password VARCHAR(255),
    name VARCHAR(255),
    role ENUM('user', 'admin') DEFAULT 'user',
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    profile_image VARCHAR(255),
    verification_code VARCHAR(6),
    verification_expires DATETIME,
    last_seen DATETIME,
    is_online BOOLEAN DEFAULT FALSE,
    -- فیلدهای پروفایل کامل
    bio TEXT,
    city VARCHAR(255),
    province VARCHAR(255),
    birth_date DATE,
    skills JSON DEFAULT '[]',
    experience INT DEFAULT 0 COMMENT 'سال‌های سابقه کار',
    education VARCHAR(255),
    instagram VARCHAR(255),
    telegram VARCHAR(255),
    website VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- جدول پیام‌ها (چت)
CREATE TABLE chats (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    message TEXT,
    message_type ENUM('text', 'image', 'video', 'voice') DEFAULT 'text',
    media_url VARCHAR(255),
    reply_to_id INT,
    is_delivered BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    is_encrypted BOOLEAN DEFAULT FALSE,
    is_edited BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reply_to_id) REFERENCES chats(id) ON DELETE SET NULL,
    INDEX idx_chat_users (sender_id, receiver_id)
);

-- اگر جدول chats از قبل وجود داره، این دستورات رو اجرا کن:
-- ALTER TABLE chats ADD COLUMN is_delivered BOOLEAN DEFAULT FALSE AFTER reply_to_id;
-- ALTER TABLE chats ADD COLUMN is_edited BOOLEAN DEFAULT FALSE AFTER is_encrypted;
-- ALTER TABLE chats ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE AFTER is_edited;

-- جدول آگهی‌های استخدام
CREATE TABLE job_ads (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(255) NOT NULL,
    daily_bags INT,
    salary BIGINT NOT NULL,
    location VARCHAR(255) NOT NULL,
    province VARCHAR(255),
    phone_number VARCHAR(11) NOT NULL,
    description TEXT,
    has_insurance BOOLEAN DEFAULT FALSE COMMENT 'بیمه دارد',
    has_accommodation BOOLEAN DEFAULT FALSE COMMENT 'محل خواب دارد',
    has_vacation BOOLEAN DEFAULT FALSE COMMENT 'تعطیلات دارد',
    vacation_days INT DEFAULT 0 COMMENT 'تعداد روز تعطیلی در ماه',
    images JSON DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE,
    is_approved BOOLEAN DEFAULT FALSE,
    views INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_job_category (category),
    INDEX idx_job_location (location),
    INDEX idx_job_status (is_active, is_approved)
);


-- جدول کارجوها
CREATE TABLE job_seekers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    name VARCHAR(255) NOT NULL,
    age INT,
    experience INT DEFAULT 0,
    skills JSON DEFAULT '[]',
    expected_salary BIGINT,
    location VARCHAR(255),
    province VARCHAR(255),
    phone_number VARCHAR(11),
    description TEXT,
    profile_image VARCHAR(255),
    is_married BOOLEAN DEFAULT FALSE,
    is_smoker BOOLEAN DEFAULT FALSE,
    has_addiction BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_approved BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- جدول آگهی‌های نانوایی (فروش/اجاره)
CREATE TABLE bakery_ads (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    type ENUM('sale', 'rent') NOT NULL,
    sale_price BIGINT,
    rent_deposit BIGINT,
    monthly_rent BIGINT,
    location VARCHAR(255) NOT NULL,
    province VARCHAR(255),
    lat DECIMAL(10, 8),
    lng DECIMAL(11, 8),
    phone_number VARCHAR(11) NOT NULL,
    images JSON DEFAULT '[]',
    flour_quota INT COMMENT 'سهمیه آرد (کیسه در ماه)',
    bread_price INT COMMENT 'قیمت نان (تومان)',
    is_active BOOLEAN DEFAULT TRUE,
    is_approved BOOLEAN DEFAULT FALSE,
    is_paid BOOLEAN DEFAULT FALSE,
    views INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- جدول آگهی‌های تجهیزات
CREATE TABLE equipment_ads (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price BIGINT NOT NULL,
    `condition` ENUM('new', 'used') DEFAULT 'used',
    location VARCHAR(255) NOT NULL,
    province VARCHAR(255),
    lat DECIMAL(10, 8),
    lng DECIMAL(11, 8),
    phone_number VARCHAR(11) NOT NULL,
    images JSON DEFAULT '[]',
    videos JSON DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE,
    is_approved BOOLEAN DEFAULT FALSE,
    is_paid BOOLEAN DEFAULT FALSE,
    views INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- جدول نظرات و امتیازها
CREATE TABLE reviews (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    target_type ENUM('job_ad', 'bakery_ad', 'equipment_ad', 'user') NOT NULL,
    target_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    tags JSON DEFAULT '[]',
    is_approved BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_review_target (target_type, target_id)
);

-- جدول کاربران بلاک شده
CREATE TABLE blocked_users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    blocked_user_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (blocked_user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE INDEX idx_block_unique (user_id, blocked_user_id)
);

-- جدول اعلان‌ها
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'success', 'warning', 'error') DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_notification_user (user_id, is_read)
);
