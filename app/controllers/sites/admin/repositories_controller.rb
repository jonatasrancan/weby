class Sites::Admin::RepositoriesController < ApplicationController
  before_filter :require_user
  before_filter :check_authorization
  
  helper_method :sort_column

  respond_to :html, :xml, :js, :json
  def index
    params[:mime_type] ||= params[:empty_filter]
    params[:mime_type].try(:delete, "")
    params[:direction] ||= 'desc'

    @repositories = Repository.
      description_or_filename(params[:search]).
      order(sort_column + ' ' + sort_direction).
      page(params[:page]).per(per_page)

    @repositories = @repositories.content_file(params[:mime_type]) if params[:mime_type]

    respond_with(:site_admin, @repositories) do |format|
      format.json do
        render json: {
          current_page: @repositories.current_page,
          num_pages: @repositories.num_pages,
          repositories: @repositories
        }
      end
      if params[:template] 
        format.html { render "#{params[:template]}" }
        format.js { render "#{params[:template]}" }
      end
    end
  end

  def recycle_bin
    params[:sort] ||= 'repositories.deleted_at'
    params[:direction] ||= 'desc'
    @repositories = current_site.repositories.trashed.
    order("#{params[:sort]} #{sort_direction}").
    page(params[:page]).per(per_page)
  end

  def show
    @repository = current_site.repositories.find(params[:id])
    respond_with(:site_admin, @repository)
  end

  def new
    @repository = current_site.repositories.new
  end

  def edit
    @repository = current_site.repositories.find(params[:id])
  end

  def create
    @repository = current_site.repositories.new(params[:repository])
    respond_with(:site_admin, @repository) do |format|
      if @repository.save
        format.html do
          if params[:from] != 'other'
            redirect_to([:site, :admin, @repository])
          else
            redirect_to :back
          end
        end
        format.json do
          render json: { :repositories => @repository,
                         :message => t("successfully_created"),
                         :url => site_admin_repository_path(@repository) },
            content_type: check_accept_json
        end
        record_activity("uploaded_file", @repository)
      else
        format.html { render action: :new }
        format.json do
          render json: { :errors => @repository.errors.full_messages }, status: 412,
            content_type: check_accept_json
        end
      end
    end
  end

  def update
    @repository = current_site.repositories.find(params[:id])

    if @repository.update_attributes(params[:repository]) 
      flash[:success] = t("successfully_updated") 
      record_activity("updated_file", @repository)
      redirect_to [:site, :admin, @repository]
    else
      render action: :edit
    end
  end

  def destroy
    @repository = current_site.repositories.unscoped.find(params[:id])
    if @repository.trash
      if @repository.persisted?
        record_activity("moved_file_to_recycle_bin", @repository)
        flash[:success] = t('moved_file_to_recycle_bin')
      else
        record_activity("destroyed_file", @repository)
        flash[:success] = t('successfully_deleted')
      end
      
    else
      flash[:error] = @repository.errors.full_messages.join(", ")
    end
    
    redirect_to :back
  end

  def recover                                      
    @repository = current_site.repositories.trashed.find(params[:id])
    if @repository.untrash
      flash[:success] = t('successfully_restored')
    end
    record_activity("restored_file", @repository)
    redirect_to :back                              
  end

  private
  def sort_column
    Repository.column_names.include?(params[:sort]) ? params[:sort] : 'id'
  end

  def check_accept_json
    request.env['HTTP_ACCEPT'].include?('application/json') ?
      'application/json' :
      'text/plain'
  end

  def per_page
    params[:format] == 'json' ? 50 : params[:per_page] || per_page_default
  end
end
