<?php
/* Settings for api/contact.php. The real file is made on the server only, in
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
];
