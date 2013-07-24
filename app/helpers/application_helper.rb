module ApplicationHelper
  
  def amazon_instance_types
    options_for_select([
                           ['Micro (Up to 2 EC2 Compute Units, 613 MB RAM)', 't1.micro'],
                           #['Small (1 EC2 Compute Unit, 1.7 GB RAM)', "m1.small"],
                           #['Medium (2 EC2 Compute Unit, 3.75 GB RAM)', "m1.medium"],
                           # ["Large (4 EC2 Compute Unit, 1.7 GB RAM)", "m1.large"],
                           # ["Extra Large (8 EC2 Compute Unit, 15 GB RAM)", "m1.xlarge"],
                           #['High-CPU Medium (5 EC2 Compute Unit, 1.7 GB RAM)', "c1.medium"],
                           #['High-CPU Extra Large (20 EC2 Compute Unit, 7 GB RAM)', "c1.xlarge"]
                       ])
  end
  
  def list_of_ec2_vm_types
    options_for_select([
                           ["Micro (0.5 CPU, 613 MB RAM)", "t1.micro"],
                           ["Small (1 CPU, 2 GB RAM)", "m1.small"],
                           # ["Medium (2 CPU, 4 GB RAM)", "m1.medium"],
                           # ["Large (4 EC2 Compute Unit, 1.7 GB RAM)", "m1.large"],
                           # ["Extra Large (8 EC2 Compute Unit, 15 GB RAM)", "m1.xlarge"],
                           ["Medium (5 CPU, 2 GB RAM)", "c1.medium"],
                           ["Large (20 CPU, 7 GB RAM)", "c1.xlarge"]
                       ])
  end

end
