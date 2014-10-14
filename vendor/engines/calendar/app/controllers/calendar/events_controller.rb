module Calendar
  class EventsController < Calendar::ApplicationController
    include ActsToSort

    layout :choose_layout

    helper_method :sort_column
    before_action :check_current_site

    respond_to :html, :js, :json, :rss

    def index
      @events = get_events

      respond_with(@events) do |format|
        format.rss { render layout: false, content_type: Mime::XML } # index.rss.builder
        format.atom { render layout: false, content_type: Mime::XML } # index.atom.builder
      end
    end

    def show
      @event = Calendar::Event.where(site_id: current_site.id).find(params[:id])
      if request.path != event_path(@event)
        redirect_to event_path(@event), status: :moved_permanently
        return
      end
    end

    private

    def tags
      params[:tags].split(',').map { |tag| tag.mb_chars.downcase.to_s }
    end

    def get_events
      params[:direction] ||= 'desc'
      # Vai ao banco por linha para recuperar
      # tags e locales
      events = Calendar::Event.where(site_id: current_site.id).
        search(params[:search], params.fetch(:search_type, 1).to_i).
        order(sort_column + ' ' + sort_direction).
        page(params[:page]).per(params[:per_page])

      events = events.tagged_with(tags, any: true) if params[:tags]
      events
    end

    def sort_column
      params[:sort] || 'calendar_events.id'
    end

    def check_current_site
      render_404 unless current_site
    end
  end
end