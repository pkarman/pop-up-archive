namespace :users do

  # create User accounts singly or from a file
  # examples:
  #
  # single User
  # % rake users:create['Jill','jill@someplace.com']
  # 
  # single User in an Org with id 123
  # % rake users:create['Jill','jill@someplace.com'] ORG_ID=123
  #
  # list of Users in Org 456
  # % cat users
  # Joe, joe@foo.com
  # Jill, jill@bar.edu
  # % rake users:create_from_file[users] ORG_ID=456
  #
  # add existing Users to an org 789
  # % cat users
  # joe@foo.com
  # jill@bar.com
  # % rake users:add_to_org[users] ORG_ID=789
  #
  # use the DRY_RUN=1 env var to validate data without actually writing to the db.
  # use the VERBOSE=1 env var to print out values as they are processed.
  #

  VALID_EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i

  desc "Create an account"
  task :create, [:username, :email] => [:environment] do |t,args|
    username = args.username
    email    = args.email
    create_user username, email
  end

  def create_user(username, email)
    verbose = ENV['VERBOSE'] || false
    dry_run = ENV['DRY_RUN'] || false
    org_id  = ENV['ORG_ID'] || nil

    # sanity check on name and email
    if username.length == 0
      raise "username cannot be empty"
    end
    if email.length == 0 or !email.match(VALID_EMAIL_REGEX)
      raise "suspicious email value: #{email}"
    end
    pw = Utils::generate_rand_str
    verbose and puts "username:#{username} email:#{email} pw:#{pw} org_id:#{org_id}"
    if !dry_run
      user = User.new({ name: username, email: email, password: pw })
      if org_id
        user.organization_id = org_id.to_i
      end
      user.save!
    end
  end

  desc "Create accounts from file"
  task :create_from_file, [:filename] => [:environment] do |t,args|
    File.readlines(args.filename).grep(/^\w/).each do |line|
      fields = line.chomp.split(/\ *\,\ */)
      puts "line=#{line}  fields=#{fields.inspect}"
      un = fields[0]
      em = fields[1]
      create_user un, em
    end
  end

  desc "Add existing Users to an Organization"
  task :add_to_org, [:filename] => [:environment] do |t,args|
    org_id = ENV['ORG_ID'] or raise "ORG_ID must be defined"
    org = Organization.find org_id.to_i
    File.readlines(args.filename).grep(/^\w/).each do |line|
      email = line.chomp
      user = User.find_by_email email
      if !user
        raise "Failed to find user #{email}"
      end
      org.add_to_team user
    end

  end

  desc "Update user subsription plan in mixpanel"
  task mixpanel_plan: [:environment] do
    User.all.each do |user|
      MixpanelPeopleWorker.perform_async(user.email, {'$plan' => user.plan_id})
    end
  end

end
