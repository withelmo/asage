require "yaml"

module Asage
  class Attribute
    attr_accessor :attribute_file, :app_name, :instance_type, :key_name,
                  :security_group_ids, :user_data, :role_name, :min_size,
                  :max_size, :load_balancer_names, :subnet_ids

    def initialize(attribute_file)
      self.attribute_file = attribute_file

      if self.exists?
        attributes = YAML.load_file(attribute_file)
        self.app_name = attributes.keys.first

        attribute = attributes[self.app_name]
        self.instance_type       = attribute["instance_type"]
        self.key_name            = attribute["key_name"]
        self.security_group_ids  = attribute["security_group_ids"]
        self.user_data           = attribute["user_data"]
        self.role_name           = attribute["role_name"]
        self.min_size            = attribute["min_size"]
        self.max_size            = attribute["max_size"]
        self.load_balancer_names = attribute["load_balancer_names"]
        self.subnet_ids          = attribute["subnet_ids"]
      end
    end

    def exists?
      File.exist?(self.attribute_file.to_s)
    end

    def asg_name_generator
      "#{self.app_name}_asg"
    end

    def lc_prefix_generator
      "#{self.app_name}_lc_"
    end

    def lc_name_generator
      "#{lc_prefix_generator}#{Time.now.to_i}"
    end

    def ami_name_generator
      "#{self.app_name}_for_asg_#{Time.now.to_i}"
    end

    def to_h
      self.instance_variables.each_with_object({}) do |attr, hash|
        hash[attr.to_s.delete("@")] = self.instance_variable_get(attr)
      end
    end

    def to_yaml
      h = self.to_h
      h.delete("attribute_file")
      h.delete("app_name")
      attributes_hash = {self.app_name => h}

      File.open(self.attribute_file, 'w') do |f|
        YAML.dump(attributes_hash, f)
      end
    end

    def present?(attr)
      !blank?(attr)
    end

    def blank?(attr)
      self.send(attr).nil? || self.send(attr).empty?
    end
  end
end
