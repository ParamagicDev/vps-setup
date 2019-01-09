# frozen_string_literal: true

require 'fileutils'
require 'os' # returns users OS

module VpsSetup
  # Copies config from /vps-setup/config to your home dir
  class Copy
    def self.copy(backup_dir: nil, dest_dir: nil, ssh_dir: nil)
      raise 'Please run from a posix platform' unless OS.posix?

      root = (Process.uid.zero? || Dir.home == '/root')
      raise 'Do not run this as root, use sudo instead' if root == true

      backup_dir ||= File.join(Dir.home, 'backup_config')
      dest_dir ||= Dir.home

      mkdirs(backup_dir, dest_dir)

      copy_config_dir(backup_dir, dest_dir)
      link_vim_to_nvim(backup_dir, dest_dir)
      copy_gnome_settings(backup_dir)
      copy_sshd_config(backup_dir, ssh_dir)

      puts "dotfiles copied to #{dest_dir}"
      puts "backups created @ #{backup_dir}"
    end

    def self.copy_config_dir(backup_dir, dest_dir)
      # Dir.children(CONFIG_DIR).each do |file|, released in ruby 2.5.1
      # in 2.3.3 which is shipped with babun
      linux = OS.linux?

      Dir.foreach(CONFIG_DIR).each do |file|
        # Explanation of this regexp in test/test_copy_confib.rb
        # .for_each returns '.' and '..' which we dont want
        next if file =~ /\A\.{1,2}\Z/
        next if NON_DOTFILES.include?(file)

        config = File.join(CONFIG_DIR, file)
        dot = File.join(dest_dir, ".#{file}")
        backup = File.join(backup_dir, "#{file}.orig")

        copy_unix_files(config, dot, backup) if linux || OS.mac?
        copy_cygwin_files(config, dot, backup) if OS.cygwin?
      end
    end

    def self.sshd_copyable?(ssh_dir = nil)
      ssh_dir ||= '/etc/ssh'

      no_ssh_dir = 'No ssh dir found. sshd_config not copied'
      return puts no_ssh_dir unless Dir.exist?(ssh_dir)

      true
    end

    def self.copy_sshd_config(backup_dir, ssh_dir = nil)
      ssh_dir ||= '/etc/ssh'

      return unless sshd_copyable?(ssh_dir)

      sshd_cfg_path = File.join(CONFIG_DIR, 'sshd_config')
      sshd_backup = File.join(backup_dir, 'sshd_config.orig')
      sshd_path = File.join(ssh_dir, 'sshd_config')

      if File.exist?(sshd_path) && !(File.exist?(sshd_backup))
        Rake.cp(sshd_path, sshd_backup)
      else
        puts "#{sshd_backup} already exists. no backup created"
      end
      puts "copying to #{sshd_path}"
      Rake.sh("sudo cp #{sshd_cfg_path} #{sshd_path}")
    end

    def self.dot_file_found?(file)
      return true if File.exist?(file)

      puts "#{file} does not exist. No backup created."
      false
    end

    def self.backup_file_not_found?(file)
      return true unless File.exist?(file)

      puts "#{file} exists already. No backup created."
      false
    end

    # helper method to run within a file list
    def self.copy_unix_files(config_file, dot_file, backup_file)
      non_unix_files = %w[cygwin_zshrc minttyrc]
      return if non_unix_files.include?(File.basename(config_file))

      copy_files(config_file, dot_file, backup_file)
    end

    def self.copy_cygwin_files(config_file, dot_file, backup_file)
      non_cygwin_files = %w[zshrc]
      return if non_cygwin_files.include?(File.basename(config_file))

      if File.basename(config_file) == 'cygwin_zshrc'
        # Converts cygwin_zshrc to .zshrc for cygwin environment use
        dot_file = File.join(File.dirname(dot_file), '.zshrc')
        backup_file = File.join(File.dirname(backup_file), '.zshrc.orig')
      end

      copy_files(config_file, dot_file, backup_file)
    end

    def self.copy_files(config_file, dot_file, backup_file)
      # if there is an original dot file & no backup file in the backupdir
      if dot_file_found?(dot_file)
        if backup_file_not_found?(backup_file)
          # Copy the dot file to the backup dir
          Rake.cp(dot_file, backup_file)
        end
      end

      # Copies from vps-setup/config to home_dir
      Rake.cp(config_file, dot_file)
    end

    def self.mkdirs(*dirs)
      dirs.each { |dir| Rake.mkdir_p(dir) unless Dir.exist?(dir) }
    end

    def self.link_vim_to_nvim(backup_dir, dest_dir)
      return unless OS.linux?

      nvim_path ||= File.join(dest_dir, '.config', 'nvim', 'init.vim')
      Rake.mkdir_p(File.dirname(nvim_path)) unless Dir.exist?(File.dirname(nvim_path))

      backup = File.join(backup_dir, '.init.vim.orig')
      vimrc = File.join(dest_dir, '.vimrc')

      Rake.cp(nvim_path, backup) if File.exist?(nvim_path)
      Rake.ln_sf(vimrc, nvim_path)
    end

    def self.copy_gnome_settings(backup_dir)
      backup = "#{backup_dir}/gnome_terminal_settings.orig"
      Rake.sh("dconf dump /org/gnome/terminal/ > #{backup}")
      Rake.sh('dconf reset -f /org/gnome/terminal/')
      Rake.sh("dconf load /org/gnome/terminal/ < #{CONFIG_DIR}/gnome_terminal_settings")
    rescue RuntimeError => error
      warn error.message
      puts 'something went wrong with gnome, continuing on'
    end
  end
end