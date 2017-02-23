module Stemcell
  class Builder
    class Base
      def initialize(os:, output_dir:, version:, agent_commit:, packer_vars:)
        @os = os
        @output_dir = output_dir
        @version = version
        @agent_commit = agent_commit
        @packer_vars = packer_vars
      end

      def build(iaas:, is_light:, image_path:, manifest:)
        apply_spec = ApplySpec.new(@agent_commit).dump
        Packager.package(iaas: iaas, os: @os, is_light: is_light, version: @version, image_path: image_path, manifest: manifest,
                     apply_spec: apply_spec, output_dir: @output_dir)
      end

      private

        def exec_command(cmd)
          `#{cmd}`
          raise "command '#{cmd}' failed" unless $?.success?
        end
    end

    class Aws < Base
      def initialize(amis:, **args)
        @amis = amis
        super(args)
      end

      def build
        manifest = Manifest::Aws.new(@version, @os, @amis).dump
        super(iaas: 'aws', is_light: true, image_path: '', manifest: manifest)
      end
    end

    class Gcp < Base
      def build
        manifest = Manifest::Gcp.new(@version, @os, '').dump
        super(iaas: 'gcp', is_light: true, image_path: '', manifest: manifest)
      end
    end

    class Azure < Base
      def build
        image_path = create_image
        sha = Digest::SHA1.file(image_path).hexdigest
        manifest = Manifest::Azure.new('bosh-azure-stemcell-name', @version, sha, @os).dump
        super(iaas: 'azure', is_light: false, image_path: image_path, manifest: manifest)
      end

      private
        def packer_config
          Packer::Config::Azure.new().dump
        end

        def create_image
          packer_output = Packer::Runner.new(packer_config).run('build', @packer_vars)
          disk_uri = nil
          packer_output.each_line do |line|
            # puts line
            disk_uri ||= parse_disk_uri(line)
          end
          download_disk(disk_uri)
          Packager.package_image(image_path: "#{@output_dir}/root.vhd", archive: true, output_dir: @output_dir)
        end

        def parse_disk_uri(line)
          unless line.include?("azure-arm,artifact,0") and line.include?("OSDiskUriReadOnlySas:")
            return
          end
          (line.split '\n').select do |s|
            s.start_with?("OSDiskUriReadOnlySas: ")
          end.first.gsub("OSDiskUriReadOnlySas: ", "")
        end

        def download_disk(disk_uri)
          exec_command("curl -o '#{@output_dir}/root.vhd' '#{disk_uri}'")
        end
    end
  end
end