require 'openid'
require 'openid/extensions/ax'

require 'openid_providers/google_openid'
require 'openid_providers/plgrid_openid'

require 'utils'

class UserControllerController < ApplicationController
  include UserControllerHelper
  include GoogleOpenID
  include PlGridOpenID

  def successful_login
    original_url = session[:original_url]
    session[:original_url] = nil

    flash[:notice] = t('login_success')
    Rails.logger.debug('[authentication] successful')

    @user_session = UserSession.create_and_update_session(session[:user].to_s,
                                                          session[:uuid])

    redirect_to (original_url or root_path)
  end

  def login
    if request.post?
      begin
        config = Utils::load_config
        anonymous_login = config['anonymous_login']
        username = params.include?(:username) ? params[:username].to_s : anonymous_login.to_s

        requested_user = ScalarmUser.find_by_login(username)
        raise t('user_controller.login.user_not_found') if requested_user.nil?

        if requested_user.banned_infrastructure?('scalarm')
          raise t('user_controller.login.login_banned', time: requested_user.ban_expire_time('scalarm'))
        end

        session[:user] = ScalarmUser.authenticate_with_password(username, params[:password]).id.to_s
        session[:uuid] = SecureRandom.uuid

        if requested_user.credentials_failed and requested_user.credentials_failed.include?('scalarm')
          requested_user.credentials_failed['scalarm'] = []
          requested_user.save
        end

        successful_login
      rescue Exception => e
        Rails.logger.debug("Exception on login: #{e}\n#{e.backtrace.join("\n")}")
        reset_session
        flash[:error] = e.to_s

        unless requested_user.nil?
          requested_user.credentials_failed = {} unless requested_user.credentials_failed
          requested_user.credentials_failed['scalarm'] = [] unless requested_user.credentials_failed.include?('scalarm')
          requested_user.credentials_failed['scalarm'] << Time.now
          requested_user.save
        end

        redirect_to login_path
      end
    end
  end

  def logout
    keep_session_params(:server_name) do
      reset_session
    end
    @user_session.destroy unless @user_session.blank?
    @current_user.destroy_unused_credentials unless @current_user.nil?

    flash[:notice] = t('logout_success')

    redirect_to login_path
  end

  def change_password
    if params[:password] != params[:password_repeat]

      flash[:error] = t('password_repeat_error')

    elsif params[:password].length < 8 or (/\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.match(params[:password]).nil?)

      flash[:error] = t('password_too_weak')

    elsif (not @current_user.password_hash.nil?)

      begin
        ScalarmUser.authenticate_with_password(@current_user.login, params[:current_password])
      rescue Exception => e
        flash[:error] = t('password_wrong')
      end

    end

    if flash[:error].blank?
      @current_user.password = params[:password]
      @current_user.save

      flash[:notice] = t('password_changed')
    end

    redirect_to :action => 'account'
  end

  def status
    tests = Utils.parse_json_if_string(params[:tests])

    status = 'ok'
    message = ''

    unless tests.nil?
      failed_tests = tests.select { |t_name| not send("status_test_#{t_name}") }

      unless failed_tests.empty?
        status = 'failed'
        message = "Failed tests: #{failed_tests.join(', ')}"
      end
    end

    http_status = (status == 'ok' ? :ok : :internal_server_error)

    respond_to do |format|
      format.html do
        render text: message, status: http_status
      end
      format.json do
        render json: {status: status, message: message}, status: http_status
      end
    end
  end


  # --- Monitoring Statistics ---
  def statistics
    host = LOCAL_IP
    host.gsub!("\.", "_")

    collections = [
        "#{host}.ExperimentManager___experiments___next_simulation",
        "#{host}.ExperimentManager___simulations___mark_as_complete",
        "#{host}.StorageManager___log_bank___put_simulation_output",
        "#{host}.StorageManager___log_bank___put_stimulation_stdout",
        "#{host}.System___NULL___CPU",
        "#{host}.System___NULL___Mem",
        "#{host}.Storage___vda___await",
        "#{host}.Storage___vda___rMB_s",
        "#{host}.Storage___vda___r_s",
        "#{host}.Storage___vda___wMB_s",
        "#{host}.Storage___vda___w_s",
        "#{host}.Storage___vdb___await",
        "#{host}.Storage___vdb___rMB_s",
        "#{host}.Storage___vdb___r_s",
        "#{host}.Storage___vdb___wMB_s",
        "#{host}.Storage___vdb___w_s",
        "#{host}.System___NULL___CPU",
        "#{host}.System___NULL___Mem"
    ]

    results = Hash[
        collections.collect do |cname|
          coll = MONITORING_DB[cname]
          values = coll.find({}, {fields: { date: 1, value: 1, _id: 0 }}).sort('$natural' => -1).limit(10).collect {|doc| doc.to_h}

          [cname, values]
        end
    ]

    mark_coll = MONITORING_DB["#{host}.ExperimentManager___simulations___mark_as_complete"]
    now = Time.now - 2.second
    mark_count = mark_coll.find({date: {'$gte'=>now.change(usec: 0), '$lt'=>now.change(usec: 999999)}}).count

    results = {mark_as_complete_count: [{date: now, value: mark_count}]}.merge(results)

    experiment_id = params[:experiment_id]

    if experiment_id
      exp = Experiment.where(id: experiment_id.to_s).first
      e_stat = exp.get_statistics
      all, sent, done = e_stat
      results = {experiment: [{date: now, all: exp.experiment_size, sent: sent, done: done}]}.merge(results)
    end

    respond_to do |format|
      format.json do
        render json: results
      end
      format.text do
        render text: JSON.pretty_generate(results)
      end
    end
  end


  private

  # --- OpenID support ---

  # Get stateless mode OpenID::Consumer instance for this controller.
  def consumer
    @consumer ||= OpenID::Consumer.new(session, nil) # 'nil' for stateless mode
  end

  # --- Status tests ---

  def status_test_database
    MongoActiveRecord.available?
  end

end
