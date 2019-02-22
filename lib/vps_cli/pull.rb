# frozen_string_literal: true

require 'rake'

module VpsCli
  # Pull changes from local dir into config dir
  # to be able to push changes up to the config dir
  class Pull
    extend FileHelper

    # Base pull method
    # @see VpsCli#create_options for the defaults
    # @param [Hash] Provides options for pulling files into a
    #   specific destination directory
    # @option opts [Dir] :config_dir ('/path/to/vps_cli/config_files) Where to save the dotfiles to
    # @option opts [Dir] :backup_dir ('$HOME/backup_files') Where to backup
    #   currently existing dotfiles
    # @option opts [Dir] :local_ssh_dir ('/etc/ssh')
    #   directory containing sshd_config
    # @option opts [Boolean] :verbose (false)
    #   Whether or not to print additional info
    # @option opts [Boolean] :testing (false) used internally for tests

    def self.all(opts = {})
      opts = VpsCli.create_options(opts)

      # pulls dotfiles into specified directory
      dotfiles(opts)

      # pulls from opts[:local_sshd_config]
      sshd_config(opts)

      # pulls via dconf
      gnome_terminal_settings(opts)

    end

    def self.dotfiles(opts = {})
      opts = VpsCli.create_options(opts)

      Dir.each_child(opts[:dotfiles_dir]) do
|file|

      end
    end

    def self.sshd_config(opts = {})
      opts = VpsCli.create_options(opts)

    end

    def self.gnome_terminal_settings(opts = {})
      opts = VpsCli.create_options(opts)
    end
  end
end
