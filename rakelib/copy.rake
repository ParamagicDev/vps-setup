# frozen_string_literal: true

BACKUP_DIR = File.join(Dir.home, 'backup_files')

namespace 'config' do
  desc "copies from a config dir to backup & dest dirs.
This can be accessed via:
    $ rake config:copy
default :backup_dir to ~/backup_files
default :local_dir to ~

or with arguments:
    $ rake \"config:copy[/path/to/backup_dir, /path/to/dest_dir]\""

  # Allows the setting of a backup_dir for your dotfiles
  task :copy, [:backup_dir, :dest_dir] do |_t, args|
    args.with_defaults(backup_dir: BACKUP_DIR, dest_dir: Dir.home)

    VpsSetup::Copy.copy(backup_dir: args.backup_dir, dest_dir: args.dest_dir)
  end
end
