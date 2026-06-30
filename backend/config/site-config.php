<?php
/**
 * WABEES — Site Config
 * Centralized host/scheme for public URLs so uploads always use main domain
 * 
 * NOTE: Hostinger shared hosting — env vars not available, hardcoded values
 */

if (!defined('PUBLIC_HOST')) {
  define('PUBLIC_HOST', 'wabees.live');
}

if (!defined('PUBLIC_SCHEME')) {
  define('PUBLIC_SCHEME', 'https');
}
?>
