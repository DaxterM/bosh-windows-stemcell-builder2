#!/usr/bin/env ruby

require 'fileutils'
require 'zlib'
require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'
require 'mkmf'
#require 'nokogiri'
require_relative '../erb_templates/templates.rb'

# concourse inputs
VERSION = "1000.2.2"

AGENT_PATH = "compiled-agent/agent.zip"
AGENT_DEPS_PATH = "compiled-agent/agent-dependencies.zip"
#AGENT_COMMIT = File.read("compiled-agent/sha").chomp


OUTPUT_DIR = "/output-vmx"
MEMSIZE = "8192"
NUMVCPUS = "6"

ADMINISTRATOR_PASSWORD= "Password123!"

def gzip_file(name, output)
  Zlib::GzipWriter.open(output) do |gz|
   File.open(name) do |fp|
     while chunk = fp.read(32 * 1024) do
       gz.write chunk
     end
   end
   gz.close
  end
end

def packer_command(command, config_path)
  Dir.chdir(File.dirname(config_path)) do

    args = %{
      packer #{command} \
      -var "memsize=#{MEMSIZE}" \
      -var "numvcpus=#{NUMVCPUS}" \
      -var "administrator_password=#{ADMINISTRATOR_PASSWORD}" \
      #{config_path}
    }
    Open3.popen2e(args) do |stdin, stdout_stderr, wait_thr|
      stdout_stderr.each_line do |line|
        puts line
      end
      exit_status = wait_thr.value
      if exit_status != 0
        puts "packer failed #{exit_status}"
        exit(1)
      end
    end
  end
end

def exec_command(cmd)
  `#{cmd}`
  exit 1 unless $?.success?
end

def install_ovftool
  ovftoolBundle = "windows-stemcell-dependencies/ovftool/VMware-ovftool.bundle"
  File.chmod(0777, ovftoolBundle)
  exec_command("#{ovftoolBundle} --required --eulas-agreed")
end

def install_vmware_player
  vmwareplayerBundle = "windows-stemcell-dependencies/VMware-tools/VMware-Player.bundle"
  File.chmod(0777, vmwareplayerBundle)
  exec_command("#{vmwareplayerBundle} --required --eulas-agreed")
end

# install_ovftool
# install_vmware_player

if find_executable('ovftool') == nil
  abort("ERROR: cannot find 'ovftool' on the path")
end

if find_executable('vmplayer') == nil
  abort("ERROR: cannot find 'vmplayer' on the path")
end

if find_executable('packer') == nil
  abort("ERROR: cannot find 'packer' on the path")
end

# find sha1sum executable name
SHA1SUM='sha1sum'
if find_executable(SHA1SUM) == nil
  SHA1SUM='shasum' # OS X
  if find_executable(SHA1SUM) == nil
    abort("ERROR: cannot find 'sha1sum' or 'sha1sum' on the path")
  end
end

FileUtils.mkdir_p(OUTPUT_DIR)
output_dir = File.absolute_path(OUTPUT_DIR)

IMAGE_PATH = "#{output_dir}/image"

BUILDER_PATH=File.expand_path("../..", __FILE__)

packer_config = File.join(BUILDER_PATH, "vsphere", "packer-from-vmx.json")

packer_command('validate', packer_config)
packer_command('build', packer_config)

#ova_file = Dir.glob('**/packer-vmware-iso.ova' ).select { |fn| File.file?(fn) }
#if ova_file.length == 0
#  abort("ERROR: unable to find packer-vmware-iso.ova")
#end

# remove network interface from VM image
#Dir.mktmpdir do |dir|
#  exec_command("tar xf #{ova_file[0]} -C #{dir}")
#  f = Nokogiri::XML(File.open("#{dir}/packer-vmware-iso.ovf"))
#  f.css("VirtualHardwareSection Item").select {|x| x.to_s =~ /Ethernet 1/}.first.remove
#  File.write("#{dir}/packer-vmware-iso.ovf", f.to_s)
#  ova_file_path = File.absolute_path(ova_file[0])
#  Dir.chdir(dir) do
#    exec_command("tar cf #{ova_file_path} packer-vmware-iso.ovf packer-vmware-iso.mf packer-vmware-iso-disk1.vmdk#")
  # end
# end

# gzip_file(ova_file[0], "#{IMAGE_PATH}")

# IMAGE_SHA1=`#{SHA1SUM} #{IMAGE_PATH} | cut -d ' ' -f 1 | xargs echo -n`

# Dir.mktmpdir do |dir|
  # MFTemplate.new("#{BUILDER_PATH}/erb_templates/vsphere/stemcell.MF.erb", VERSION, sha1: IMAGE_SHA1).save(dir)
  # ApplySpecTemplate.new("#{BUILDER_PATH}/erb_templates/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
  # FileUtils.cp("#{IMAGE_PATH}", dir)

  # stemcell_filename = "bosh-stemcell-#{VERSION}-vsphere-esxi-windows2012R2-go_agent.tgz"

  # exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
# end
