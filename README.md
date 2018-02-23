# Asage


This is a simple tool for managing AWS AutoScalingGroup.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'asage'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install asage

## Usage

### All Commands
```
Commands:
  asage attributes [attribute_file]                    # Read and write parameters.
  asage change_count [attribute_file]                  # Change count of EC2 instances under auto scaling group
  asage clean_ami [image_id]                           # Clean AMI. Re-register AMI and delete snapshots.
  asage clean_lc [attribute_file, launch_config_name]  # Clean launch config. Delete launch config and re-register AMI and delete snapshots.
  asage create_asg [attribute_file, image_id]          # Create auto scaling group
  asage create_lc [attribute_file, image_id]           # Create launch config
  asage describe_asg [attribute_file]                  # Display list of auto-scaling-groups
  asage help [COMMAND]                                 # Describe available commands or one specific command
  asage update_asg [attribute_file]                    # Update auto scaling group
  asage version                                        # Display version
```

### Tour
1. Create attribute file for auto scaling group,
```
$ bundle exec asage attributes attribute_file.yaml
Application Name? new_application
Instance Type? t3.large
Key Name? ec2_key_name
Security Group IDs? sg-xxxxxxxx,sg-yyyyyyy
User Data File Path? path/to/user_data.txt
Min Size? 2
Max Size? 5
Subnet Group IDs? subnet-xxxxxxx,subnet-yyyyyy
Load Balancer Name? new_lb_name
Role Name? new_role_name
```

Or it is okay to create the file directly with any editor.

2. Create new auto scaling group,
```
$ bundle exec asage create_asg attribute_file.yaml [target AMI ID]
Created launch configuration(new_application_lc_1519371647)
Created auto scaling group(new_application_asg)
```

3. Display auto scaling group description,
```
$ bundle exec asage describe_asg attribute_file.yaml
+-------------------+-----------------------+-----------------------------+-----------------------+
|AutoScalingGroup   |AsgCreated             |LaunchConfig                 |LcCreated              |
+-------------------+-----------------------+-----------------------------+-----------------------+
|new_application_asg|2018-02-23 07:40:49 UTC|new_application_lc_1519371647|2018-02-23 07:40:47 UTC|
+----------------+-----------------------+--------------------------------+-----------------------+
+---+-------------------+----------------+--------------+------------+---------------------------------+--------------------+
|No.|InstanceID         |AvailabilityZone|LifecycleState|HealthStatus|LaunchConfigurationName          |ProtectedFromScaleIn|
+---+-------------------+----------------+--------------+------------+---------------------------------+--------------------+
|1  |i-xxxxxxxxxxxxxxxxx|us-east-1b      |InService     |Healthy     |new_application_asg_lc_1519371647|false               |
+---+-------------------+----------------+--------------+------------+---------------------------------+--------------------+
|2  |i-yyyyyyyyyyyyyyyyy|us-east-1b      |InService     |Healthy     |new_application_asg_lc_1519371647|false               |
+---+-------------------+----------------+--------------+------------+---------------------------------+--------------------+
```

4. When update auto scaling group for creating new AMI from running EC2 instance,
```
$ bundle exec asage update_asg attribute_file.yaml
Searching EC2 instances of new_application_asg [▸▹▹▹▹]
Which EC2 instance do you update auto scaling group from based on? i-xxxxxxxxxxxxxxxxx(us-east-1b)
Creating AMI(ami-xxxxxxxxx) [▹▹▹▹▸]
Created AMI(new_application_asg_for_asg_1519372804:ami-xxxxxxxxx)
Created launch configuration(new_application_lc_1519372939)
Created auto scaling group(new_application_asg)
+------------------------+-----------------------+-----------------------------+-----------------------+
|AutoScalingGroup        |AsgCreated             |LaunchConfig                 |LcCreated              |
+------------------------+-----------------------+-----------------------------+-----------------------+
|new_application_asg     |2018-02-23 07:40:49 UTC|new_application_lc_1519372939|2018-02-23 08:02:19 UTC|
+------------------------+-----------------------+---------------------+-------------------------------+
+---+-------------------+----------------+--------------+------------+-----------------------+------------------------------+
|No.|InstanceID         |AvailabilityZone|LifecycleState|HealthStatus|LaunchConfigurationName|ProtectedFromScaleIn          |
+---+-------------------+----------------+--------------+------------+-----------------------+------------------------------+
|1  |i-xxxxxxxxxxxxxxxxx|us-east-1b      |InService     |Healthy     |new_application_asg_lc_1519371647|false               |
+---+-------------------+----------------+--------------+------------+---------------------------------+--------------------+
|2  |i-yyyyyyyyyyyyyyyyy|us-east-1b      |InService     |Healthy     |new_application_asg_lc_1519371647|false               |
+---+-------------------+----------------+--------------+------------+---------------------------------+--------------------+
```

5. Change EC2 count under auto scaling group,
```
$ vi attribute_file.yaml
(modify count of min/max size)

$ bundle exec asage change_count fusic_dev.yaml
Are you sure to change count of EC2 instances under new_application_asg to max:1 and min:1 ? [yes/no] yes
The count of EC2 instances under new_application_asg was changed to max:1 and min:1.
```

6. Clean up OLD AMI,
```
$  bundle exec asage clean_lc fusic_dev.yaml
Searching launch configs [▹▹▸▹▹]
Which launch config do you delete?
‣ Cancel
  new_application_asg_lc_1519372939|ami-xxxxxxxx|t2.large|2018-02-23 08:02:21 UTC
  new_application_asg_lc_1519371647|ami-yyyyyyyy|t2.large|2018-02-23 07:40:48 UTC
>> new_application_asg_lc_1519371647(ami-yyyyyyyy)
Are you sure to delete the above launch config?[yes/no] yes
Deleted launch config(new_application_asg_lc_1519371647)
Loading AMI(ami-yyyyyyyy) detail [▹▸▹▹▹]
+---+----------------------+----------+----+
|No.|SnapshotID            |Volume[GB]|Type|
+---+----------------------+----------+----+
|1  |snap-zzzzzzzzzzzzzzzzz|8         |gp2 |
+---+----------------------+----------+----+
Are you sure to delete IAM(ami-yyyyyyyy) and above snapshots?[yes/no] yes
Deregistered IAM(ami-yyyyyyyy)
Deleted snapshot(snap-zzzzzzzzzzzzzzzzz)
Completed.
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
