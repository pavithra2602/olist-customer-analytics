-- Fix: product_category_translation CSV has Windows line endings (\r\n), so
-- product_category_name_english kept a hidden \r character. Found in the Chart 3 labels.
USE olist_db;

SET SQL_SAFE_UPDATES = 0;

UPDATE product_category_translation
SET product_category_name_english = TRIM(TRAILING CHAR(13) FROM product_category_name_english);

SET SQL_SAFE_UPDATES = 1;

-- Check: should return 0
SELECT COUNT(*) AS rows_with_cr
FROM product_category_translation
WHERE product_category_name_english LIKE CONCAT('%', CHAR(13));