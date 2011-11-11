class mysql::server::cron::backup {

    $real_mysql_backup_dir = $mysql_backup_dir ? {
        '' => '/var/backups/mysql',
        default => $mysql_backup_dir,
    }
    
    $mysql_cleanup_after = $mysql_cleanup_after ? {
        '' => false,
        default => $mysql_cleanup_after,
    }
    
    $mysql_backup_s3 = $mysql_backup_s3 ? {
        '' => false,
        default => $mysql_backup_s3,
    }

    case $mysql_manage_backup_dir {
      false: { info("We don't manage \$mysql_backup_dir ($mysql_backup_dir)") }
      default: {
        file { 'mysql_backup_dir':
          path => $real_mysql_backup_dir,
          ensure => directory,
          before => Cron['mysql_backup_cron'],
          owner => root, group => 0, mode => 0700;
        }
      }
    }

    cron { 'mysql_backup_cron':
        command => "/usr/bin/mysqldump --default-character-set=utf8 --all-databases --create-options --flush-logs --lock-tables --single-transaction | gzip > ${real_mysql_backup_dir}/mysqldump.sql.$(date +%Y-%m-%d).gz",
        user => 'root',
        minute => 0,
        hour => 1,
        require => [ Exec['mysql_set_rootpw'], File['mysql_root_cnf'] ],
   }
   
  if $mysql_cleanup_after {
    cron { 'mysql_backup_cleanup':
      command => "find ${real_mysql_backup_dir} -mtime +${mysql_cleanup_after} -exec rm {} \;",
      user => 'root',
      minute => 0,
      hour => 2,
      require => [ Cron['mysql_backup_cron'] ],

    }
  } 
   
  if $mysql_backup_s3 {
    include s3cmd
    
    cron { 'mysql_backup_s3':
      command => "s3cmd sync --delete-removed --skip-existing ${real_mysql_backup_dir}/ s3://${s3_bucket}/databases/",
      user => 'root',
      minute => 5,
      hour => 2,
      require => [ Cron['mysql_backup_cron'] ],
    }
  }
   
}
