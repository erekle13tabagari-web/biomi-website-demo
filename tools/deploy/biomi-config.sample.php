<?php
/* Settings for api/contact.php and api/decap-auth.php. The real file is made on the server only, in
   DirectAdmin's File Manager, beside public_html (never inside it):

       /home/biomige/domains/test.biomi.ge/biomi-config.php   (test site)
       /home/biomige/domains/biomi.ge/biomi-config.php        (real site)

   Never put the real password in this sample or anywhere in the project. */
return [
  'db_host'   => 'localhost',
  'db_name'   => 'biomige_forms',
  'db_user'   => 'biomige_forms',
  'db_pass'   => 'PASTE-THE-DATABASE-PASSWORD-HERE',
  'mail_to'   => 'marketing@biomi.ge',
  'mail_from' => 'marketing@biomi.ge',
  // the content editor's GitHub sign-in (api/decap-auth.php), test site only:
  // the OAuth App "Biomi content editor" at github.com/settings/developers
  'github_client_id'     => 'PASTE-THE-CLIENT-ID-HERE',
  'github_client_secret' => 'PASTE-THE-CLIENT-SECRET-HERE',
];
