# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'stringio'
require 'logger'


LOG_PATH = File.join(LOGS_DIR, "#{File.basename(__FILE__, '.rb')}.log")
LOG_FILE = File.new(LOG_PATH, 'w+')
LOGGER = Logger.new(LOG_FILE)

class TestCopy < Minitest::Test
  include VpsSetup


  def setup
    LOGGER.info("#{class_name}::#{name}")
    @console = capture_console
    @linux_copy = {}
    remove_dirs(BACKUP_DIR, DEST_DIR)
  end

  def teardown
    LOGGER.info(@console[:fake_out].string)
    LOGGER.error(@console[:fake_err].string)

    restore_out_err(@console)
    remove_dirs(BACKUP_DIR, DEST_DIR)
  end

  # HELPER METHODS #
  def dir_children(dir)
    # Reads as \A == beginning of string
    # \. == '.' {1,2} means minimum 1, maximum 2 occurences
    # \Z == end of string
    Dir.foreach(dir).reject { |file| file =~ /\A\.{1,2}\Z/ }
  end

  def remove_dirs(*args)
    args.each { |dir| FileUtils.rm_rf(dir) if Dir.exist?(dir) }
  end

  def linux_env
    OS.stub(:posix?, true) do
      OS.stub(:linux?, true) do
        OS.stub(:cygwin?, false) do
          yield
        end
      end
    end
  end

  def cygwin_env
    OS.stub(:posix?, true) do
      OS.stub(:linux?, true) do
        OS.stub(:cygwin?, false) do
          yield
        end
      end
    end
  end

  def copy(backup_dir = BACKUP_DIR, dest_dir = DEST_DIR)
    Copy.copy(backup_dir: backup_dir, dest_dir: dest_dir)
  end

  # END OF HELPER METHODS #

  def test_creates_backup_dir_and_dest_dir
    refute(Dir.exist?(BACKUP_DIR))
    refute(Dir.exist?(DEST_DIR))

    linux_env do
      copy
    end

    assert(Dir.exist?(BACKUP_DIR))
    assert(Dir.exist?(DEST_DIR))
  end


  def test_will_not_error_if_backup_dir_and_dest_dir_exist
    FileUtils.mkdir_p(BACKUP_DIR)
    FileUtils.mkdir_p(DEST_DIR)
    assert(Dir.exist?(BACKUP_DIR))
    assert(Dir.exist?(DEST_DIR))

    linux_env do
      copy
    end

    assert(Dir.exist?(BACKUP_DIR))
    assert(Dir.exist?(DEST_DIR))
  end

  def test_backup_dir_empty_and_dest_dir_should_not_be_empty
    linux_env do
      copy
    end
    # Will not add files to the backup_dir if original dotfiles do not exist
    assert_empty(dir_children(BACKUP_DIR))

    refute_empty(dir_children(DEST_DIR))
    assert_includes(dir_children(DEST_DIR), '.vimrc')
  end

  def test_backup_dir_not_empty_if_orig_found
    FileUtils.mkdir_p(DEST_DIR)
    backup_file = File.join(BACKUP_DIR, '.vimrc.orig')
    dest_file = File.join(DEST_DIR, '.vimrc')

    File.open(dest_file, 'w+') { |file| file.puts 'test' }
    dest_file_before_copy = File.read(dest_file)

    linux_env do
      copy
    end

    refute_empty(dir_children(BACKUP_DIR))
    assert_includes(dir_children(BACKUP_DIR), '.vimrc.orig')

    assert dest_file_before_copy == File.read(backup_file)
    refute dest_file_before_copy == File.read(dest_file)
  end

  def test_backup_file_will_not_be_overwritten
    FileUtils.mkdir_p(DEST_DIR)
    FileUtils.mkdir_p(BACKUP_DIR)
    f1 = File.join(DEST_DIR, '.vimrc')
    f2 = File.join(BACKUP_DIR, '.vimrc.orig')
    File.open(f1, 'w+') { |file| file.puts '1' }
    File.open(f2, 'w+') { |file| file.puts '2' }
    Copy.copy(backup_dir: BACKUP_DIR, dest_dir: DEST_DIR)
    refute File.read(f1) == File.read(f2)
  end

  def test_config_file_will_be_copied_to_dest_dir
    config_file = File.join(CONFIG_DIR, 'vimrc')
    dest_file = File.join(DEST_DIR, '.vimrc')

    assert_raises(Errno::ENOENT) { File.read(config_file) == File.read(dest_file) }

    FileUtils.mkdir_p(DEST_DIR)
    File.open(dest_file, 'w+') { |file| file.puts 'test' }
    refute File.read(config_file) == File.read(dest_file)

    linux_env do
      copy
    end

    assert File.read(config_file) == File.read(dest_file)
  end

  def test_cygwin_files_not_copied_in_unix
    linux_env do
      copy
    end

    refute File.exist?(File.join(DEST_DIR, '.minttyrc'))
    refute File.exist?(File.join(DEST_DIR, '.cygwin_zshrc'))
  end

  def test_unix_files_not_copied_in_cygwin
    cygwin_env do
      copy
    end

    unix_zshrc = File.join(CONFIG_DIR, 'zshrc')
    cygwin_zshrc = File.join(CONFIG_DIR, 'cygwin_zshrc')
    dest_zshrc = File.join(DEST_DIR, '.zshrc')

    refute File.read(dest_zshrc) == File.read(unix_zshrc)
    assert File.read(dest_zshrc) == File.read(cygwin_zshrc)
  end

  def test_ssh_copying_works
    ssh_test_path = File.expand_path(File.join('test', 'ssh_test'))
    sshd_cfg_test_path = File.expand_path(File.join(ssh_test_path, 'sshd_config'))
    FileUtils.mkdir_p(ssh_test_path)

    # DEST_DIR included only because its required, does not effect test
    linux_env do
      copy
    end

    sshd_config = File.join(CONFIG_DIR, 'sshd_config')
    assert File.read(sshd_cfg_test_path) == File.read(sshd_config)

    FileUtils.rm_rf(ssh_test_path)
  end
end
