class EventsController < ApplicationController
  before_action :set_event, only: [:show, :edit, :update, :destroy, :event_responses]
  before_action :authenticate_user!, only: [:new, :edit, :update, :destroy]
  helper EventsHelper

  def index
    @clubs_of_member_events = []
    @club_events = []
    @pending_events = []
    @events = []
    if current_user.present? && current_user.admin?
      @events = Event.all
      @pending_events = Event.admin_pending_events
    elsif current_user.present? && current_user.advisor?
      club_period = ClubPeriod.find_by(id: current_user.active_club_periods.select { |clubperiod| clubperiod.id if current_user.advisor?(clubperiod) })
      @events = Event.approval_events
      @pending_events = club_period.events.advisor_pending_events
      @club_events = club_period.events.select { |event| event.event_responses.any? && event.event_responses.last.event_status_id == 2 } unless club_period.blank?
    elsif current_user.present? && current_user.president?
      club_period = ClubPeriod.find_by(id: current_user.active_club_periods.select { |clubperiod| clubperiod.id if current_user.president?(clubperiod) })
      @events = Event.approval_events
      @club_events = club_period.events.select { |event| event.event_responses.any? && event.event_responses.last.event_status_id == 2 } unless club_period.blank?
      @pending_events = club_period.events.president_pending_events
      @clubs_of_member_events = Event.member_club_events(current_user)
    elsif current_user.present? && current_user.member?
      @clubs_of_member_events = Event.member_club_events(current_user)
    elsif current_user.present? && current_user.dean?
      current_facult_id = current_user.roles.where(role_type_id: RoleType.find_by_name('Dekan').id, status: true).first.faculty_id
      @pending_events = Event.where(faculty_id: current_facult_id).dean_pending_events
      @events = Event.approval_events
    else
      @events = Event.approval_events
    end
    events = (@events if @events.any?) || (@clubs_of_member_events if @clubs_of_member_events.any?) || (@club_events if @club_events.any?) || (@pending_events if @pending_events.any?) || []
    authorize Event.where(id: events.map(&:id))
  end

  def event_responses
    event_responses = @event.event_responses.order('created_at DESC').order('id DESC')
    respond_to do |format|
      format.json { render json: event_responses, include: :event_status }
    end
  end

  def show
  end

  def new
    @event = Event.new
    @event.datetime = params[:datetime].to_date if params[:datetime].present?
  end

  def edit
  end

  def create
    @event = Event.new(event_params)
    respond_to do |format|
      if @event.save
        # Akademik Danışman Onayı Bekleniyor
        event_response = EventResponse.create(event_id: @event.id, event_status_id: 4)
        @event.update(event_status_id: 4)
        EventMailer.approval_to_event(@event.club_period.advisor, @event).deliver_now unless @event.club_period.advisor.blank? # akademik danışmana mail gidiyor
        if event_response
          format.html { redirect_to @event, notice: 'Etkinlik başarıyla oluşturuldu.' }
          format.json { render :show, status: :created, location: @event }
        else
          @event.destroy
          format.html { render :new }
          format.json { render json: @event.errors, status: :unprocessable_entity }
        end
      else
        format.html { render :new }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @event.update(event_params)
        format.html { redirect_to @event, notice: 'Etkinlik başarıyla güncellendi.' }
        format.json { render :show, status: :ok, location: @event }
      else
        format.html { render :edit }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @event.destroy
    respond_to do |format|
      format.html { redirect_to events_url, notice: 'Etkinlik başarıyla silindi.' }
      format.json { head :no_content }
    end
  end

  def download_events
    @start_time = params[:start_date].to_date unless params[:start_date].blank?
    @finish_time = params[:finish_date].to_date unless params[:finish_date].blank?
    @event_list =
      if @start_time.present? && @finish_time.present?
        Event.where('date(datetime) BETWEEN ? AND ?', @start_time, @finish_time)
      elsif @start_time.blank? && @finish_time.present?
        Event.where('date(datetime) <= ?', @finish_time)
      elsif @start_time.present? && @finish_time.blank?
        Event.where('date(datetime) >= ?', @start_time)
      else
        Event.all
      end
    @event_list = @event_list.where(club_period_id: params[:club_period_id].to_i) unless params[:club_period_id].blank?
    if params[:state] == 'onay'
      @event_list = @event_list.select { |x| x.event_responses.last.event_status_id == 2 }
    elsif params[:state] == 'wait'
      @event_list = @event_list.select { |x| x.event_responses.last.event_status_id != 2 }
    end
    respond_to(:xlsx)
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.fetch(:event, {}).permit(:club_period_id, :event_category_id, :faculty_id, :title, :speakers, :datetime, :location, :content, :requirements, :image, :attachment, :is_admin_confirmation_ok, :is_advisor_confirmation_ok)
  end
end
