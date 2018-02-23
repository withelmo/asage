require "asage/version"
require "asage/attribute"
require "thor"
require "aws-sdk"
require "tty"
require "pry"

module Asage

  class CLI < Thor

    def initialize(*args)
      super
      @attributes = Asage::Attribute.new(args[0][0])
    end

    desc 'version', 'Display version'
    def version
      puts Asage::VERSION
    end

    desc 'attributes [attribute_file]', 'Read and write parameters.'
    def attributes(attribute_file)
      if @attributes.exists?
        ans = prompt.ask("Attribute file(#{attribute_file}) already exists. Are you sure to overwrite it?[yes/no]")

        unless ans == "yes"
          puts "Canceled."
          return
        end
      end

      @attributes.app_name            = prompt.ask("Application Name?")
      @attributes.instance_type       = prompt.ask("Instance Type?")
      @attributes.key_name            = prompt.ask("Key Name?")
      @attributes.security_group_ids  = prompt.ask("Security Group IDs?")
      @attributes.user_data           = prompt.ask("User Data File Path?")
      @attributes.min_size            = prompt.ask("Min Size?"){|q| q.convert :int}
      @attributes.max_size            = prompt.ask("Max Size?"){|q| q.convert :int}
      @attributes.subnet_ids          = prompt.ask("Subnet Group IDs?")

      @attributes.load_balancer_names = prompt.ask("Load Balancer Name?")
      @attributes.role_name           = prompt.ask("Role Name?")

      @attributes.to_yaml
    end

    desc 'describe_asg [attribute_file]', 'Display list of auto-scaling-groups'
    def describe_asg(attribute_file)
      # s = spinner("Searching auto scaling groups [:spinner]")
      a = asg.describe_auto_scaling_groups
              .auto_scaling_groups
              .select {|asg| asg.auto_scaling_group_name == @attributes.asg_name_generator}
              .first
      # s.stop

      lc_name = a.launch_configuration_name
      lc_created_at = lc_name
                          .match(Regexp.new("#{@attributes.lc_prefix_generator}(.*)"))[1]

      display_table(%w(AutoScalingGroup AsgCreated LaunchConfig LcCreated),
                    [a.auto_scaling_group_name, a.created_time,
                     a.launch_configuration_name, Time.at(lc_created_at.to_i).utc])

      if a.instances.empty?
        puts "No instances."
      else
        instances = a.instances.map.with_index(1) do |i, n|
          [n, i.instance_id, i.availability_zone, i.lifecycle_state,
           i.health_status, i.launch_configuration_name, i.protected_from_scale_in]
        end
        display_table(%w(No. InstanceID AvailabilityZone LifecycleState HealthStatus LaunchConfigurationName ProtectedFromScaleIn),
                      instances)
      end
    end

    desc 'create_lc [attribute_file, image_id]', 'Create launch config'
    def create_lc(attribute_file, image_id)
      lc_name   = @attributes.lc_name_generator
      user_data = Base64.encode64(File.open(@attributes.user_data).read)

      conf = {
          image_id:                  image_id,
          instance_type:             @attributes.instance_type,
          launch_configuration_name: lc_name,
          key_name:                  @attributes.key_name,
          security_groups:            [*@attributes.security_group_ids],
          user_data:                 user_data
      }

      if @attributes.present?(:role_name)
        conf.merge!({role_name: @attributes.role_name})
      end

      asg.create_launch_configuration(conf)
      puts "Created launch configuration(#{lc_name})"
      lc_name
    end

    desc 'create_asg [attribute_file, image_id]', 'Create auto scaling group'
    def create_asg(attribute_file, image_id)
      conf = {
          auto_scaling_group_name:   @attributes.asg_name_generator,
          launch_configuration_name: create_lc(attribute_file, image_id),
          max_size:                  @attributes.max_size,
          min_size:                  @attributes.min_size,
          vpc_zone_identifier:       @attributes.subnet_ids,
      }

      if @attributes.present?(:load_balancer_names)
        conf.merge!({load_balancer_names: [*@attributes.load_balancer_names]})
      end

      asg.create_auto_scaling_group(conf)
      puts "Created auto scaling group(#{@attributes.asg_name_generator})"
    end

    desc 'update_asg [attribute_file]', 'Update auto scaling group'
    def update_asg(attribute_file)
      asg_name = @attributes.asg_name_generator
      s = spinner("Searching EC2 instances of #{asg_name} [:spinner]")
      resp_asg = asg.describe_auto_scaling_groups({auto_scaling_group_names: ["#{asg_name}"]})
      s.stop

      selected_instance = prompt.select("Which EC2 instance do you update auto scaling group from based on?") do |menu|
        menu.choice("Cancel", nil)
        resp_asg.auto_scaling_groups[0].instances.each do |instance|
          menu.choice("#{instance.instance_id}(#{instance.availability_zone})", instance)
        end
      end

      if selected_instance.nil?
        puts "Canceled."
        return
      end

      created_ami_name = @attributes.ami_name_generator
      conf_ami = {
          instance_id: selected_instance.instance_id,
          name: created_ami_name
      }
      resp_ami = ec2.create_image(conf_ami)
      s = spinner("Creating AMI(#{resp_ami.image_id}) [:spinner]")
      ec2.wait_until(:image_available, image_ids: [resp_ami.image_id]) do |w|
        w.interval = 15
      end
      ec2.describe_images({image_ids: [resp_ami.image_id]})
      s.stop

      puts "Created AMI(#{created_ami_name}:#{resp_ami.image_id})"
      lc_name = create_lc(attribute_file, resp_ami.image_id)
      conf_asg = {
          auto_scaling_group_name:   asg_name,
          launch_configuration_name: lc_name,
      }
      asg.update_auto_scaling_group(conf_asg)
      puts "Created auto scaling group(#{asg_name})"
      describe_asg(attribute_file)
    end

    desc 'change_count [attribute_file]', 'Change count of EC2 instances under auto scaling group'
    def change_count(attribute_file)
      asg_name = @attributes.asg_name_generator
      min_size = @attributes.min_size
      max_size = @attributes.max_size
      msg = "Are you sure to change count of EC2 instances under #{asg_name} to max:#{max_size} and min:#{min_size} ? [yes/no]"

      ans = prompt.ask(msg) do |q|
        q.convert :string
      end

      unless ans == "yes"
        puts "Canceled."
        return
      end

      asg.update_auto_scaling_group({auto_scaling_group_name: asg_name,
                                     max_size: max_size,
                                     min_size: min_size})

      puts "The count of EC2 instances under #{asg_name} was changed to max:#{max_size} and min:#{min_size}."
    end

    desc 'clean_lc [attribute_file, launch_config_name]', 'Clean launch config. Delete launch config and re-register AMI and delete snapshots.'
    def clean_lc(attribute_file, lc_name = nil)
      if lc_name.nil?
        s = spinner("Searching launch configs [:spinner]")
        target_lc = asg.describe_launch_configurations.launch_configurations.select {|s|
          s.launch_configuration_name =~ Regexp.new("#{@attributes.app_name}_lc_")
        }.sort_by(&:created_time).reverse
        s.stop

        selected_lc = prompt.select("Which launch config do you delete?") do |menu|
          menu.choice("Cancel", nil)
          target_lc.each do |lc|
            menu.choice("#{lc.launch_configuration_name}|#{lc.image_id}|#{lc.instance_type}|#{lc.created_time}", lc)
          end
        end

        if selected_lc.nil?
          puts "Canceled."
          return
        end
      else
        selected_lc = asg.describe_launch_configurations({launch_configuration_names: [lc_name]})
                          .launch_configurations[0]

        if selected_lc.nil?
          puts "No launch config exist.(#{lc_name})"
          return
        end
      end

      puts ">> #{selected_lc.launch_configuration_name}(#{selected_lc.image_id})"

      ans = prompt.ask("Are you sure to delete the above launch config?[yes/no]") do |q|
        q.convert :string
      end

      unless ans == "yes"
        puts "Canceled."
        return
      end

      asg.delete_launch_configuration({launch_configuration_name: selected_lc.launch_configuration_name})
      puts "Deleted launch config(#{selected_lc.launch_configuration_name})"
      clean_ami(selected_lc.image_id)

      puts "Completed."
    end

    desc 'clean_ami [image_id]', 'Clean AMI. Re-register AMI and delete snapshots.'
    def clean_ami(image_id)
      s = spinner("Loading AMI(#{image_id}) detail [:spinner]")
      target_image = ec2.describe_images({image_ids: [image_id]}).images.first
      s.stop

      if target_image.nil?
        puts "AMI(#{image_id}) does not exist"
      else
        unless target_image.public
          target_blocks = target_image.block_device_mappings
          displayed_blocks = target_blocks.map.with_index(1) do |b, i|
            [i, b.ebs.snapshot_id, b.ebs.volume_size, b.ebs.volume_type]
          end
          display_table(%w(No. SnapshotID Volume[GB] Type), displayed_blocks)

          ans = prompt.ask("Are you sure to delete IAM(#{target_image.image_id}) and above snapshots?[yes/no]") do |q|
            q.convert :string
          end

          unless ans == "yes"
            puts "Canceled."
            return
          end

          ec2.deregister_image({image_id: target_image.image_id})
          puts "Deregistered IAM(#{target_image.image_id})"

          target_blocks.each do |b|
            ec2.delete_snapshot({snapshot_id: b.ebs.snapshot_id})
            puts "Deleted snapshot(#{b.ebs.snapshot_id})"
          end
        end
      end

    end

    private

    # AWS client generator
    def ec2
      Aws::EC2::Client.new
    end

    def asg
      Aws::AutoScaling::Client.new
    end

    # User Interface
    def display_table(header, body)
      unless body[0].kind_of? Array
        body = [body]
      end

      table = TTY::Table.new header, body
      puts table.render(:ascii)
    end

    def spinner(meg, format = :arrow_pulse)
      s = TTY::Spinner.new(meg, format: format)
      s.auto_spin
      s
    end

    def prompt
      TTY::Prompt.new
    end
  end

end
