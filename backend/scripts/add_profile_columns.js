// اسکریپت اضافه کردن ستون‌های جدید پروفایل
const sequelize = require('../config/database');

async function addProfileColumns() {
  try {
    console.log('🔄 Adding new profile columns...');
    
    const queries = [
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS city VARCHAR(255)",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS province VARCHAR(255)",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS birth_date DATE",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS skills JSON DEFAULT '[]'",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS experience INT DEFAULT 0",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS education VARCHAR(255)",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS instagram VARCHAR(255)",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram VARCHAR(255)",
      "ALTER TABLE users ADD COLUMN IF NOT EXISTS website VARCHAR(255)",
    ];

    for (const query of queries) {
      try {
        await sequelize.query(query);
        console.log('✅', query.substring(0, 60) + '...');
      } catch (e) {
        // ستون از قبل وجود داره
        if (e.message.includes('Duplicate column')) {
          console.log('⏭️ Column already exists');
        } else {
          console.log('⚠️', e.message);
        }
      }
    }

    console.log('✅ Done!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

addProfileColumns();
