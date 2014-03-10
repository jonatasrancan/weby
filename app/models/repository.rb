class Repository < ActiveRecord::Base
  include Trashable

  has_many :page,
    foreign_key: 'repository_id'

  belongs_to :site
  has_one :banner
  has_many :sites, :foreign_key => "top_banner_id", :dependent => :nullify

  has_many :pages_repositories, :dependent => :destroy
  has_many :pages, :through => :pages_repositories

  has_many :page_image, :dependent => :nullify, :class_name => 'Page'

  scope :description_or_filename, proc {|text|
    text = text.try(:downcase)
    where [ "(LOWER(description) LIKE :text OR LOWER(archive_file_name) LIKE :text)",
            { :text => "%#{text}%" } ]
  }

  scope :content_file, proc { |contents|
    if contents.is_a?(Array)
      # TODO: Esse código funcionará exclusivamente para o Postgresql
      # TODO: Corrigir para funcionar independente do banco de dados.
      contents = contents.map{|content| "%#{content.gsub("+", "\\\\+")}%"}
      where ["archive_content_type SIMILAR TO :values",
             {values: "%(#{contents.join('|')})%"}
      ]
    else
      archive_content_file(contents)
    end
  }

  scope :archive_content_file, proc { |content_file|
    where [ "LOWER(archive_content_type) LIKE :content_file",
            { :content_file => "%#{content_file.try(:downcase)}%" } ]
  }

  validates_presence_of :description

  STYLES = {
    mini: "95x70",
    litle: "190x140",
    medium: "400x300",
    thumb: "160x160^",
    original: "original"
  }

  has_attached_file :archive,
    styles: STYLES,
    url: "/uploads/:site_id/:style/:basename.:extension",
    convert_options: {
      mini: "-quality 90 -strip",
      litle: "-quality 90 -strip",
      medium: "-quality 80 -strip",
      thumb: "-crop 160x160+0+0 +repage -quality 90 -strip",
      original: "-quality 80 -strip"}

  validates_attachment_presence :archive,
    :message => I18n.t('activerecord.errors.messages.attachment_presence'), :on => :create

  before_post_process :image?, :normalize_file_name

  # Metodo para incluir a url do arquivo no json
  def archive_url(format = :original)
    self.archive.url(format)
  end

  alias :as_json_bkp :as_json

  # json alterado para enviar os dados mínimos
  def as_json(options = {})
    self.as_json_bkp only: [:id,
                            :archive_file_name,
                            :description,
                            :archive_content_type],
                            methods: :archive_url
  end

  def image?
    archive_content_type.include?("image") and not archive_content_type.include?("svg")
  end

  def svg?
    archive_content_type.include?("image") and archive_content_type.include?("svg")
  end

  def flash?
    archive_content_type.include?("flash") or archive_content_type.include?("shockwave")
  end

  # Remoção de caracteres que causava erro no paperclip
  # TODO: Rever uma melhor implementação
  def normalize_file_name
    archive.instance_write(:file_name, CGI.unescape(archive.original_filename))
  end

  validates :archive_file_name, uniqueness: {:scope => :site_id, :message => I18n.t("file_already_exists")}

  # Reprocessamento de imagens para (re)gerar os thumbnails quando necessário
  def reprocess
    archive.reprocess! if need_reprocess?
  rescue Errno::ENOENT => e
    File.open(Rails.root.join("log/error.log"), "a") do |f|
      f.write("=> Erro no reprocess: #{e}\n")
    end
  end

  def as_json options={}
    json = super(options)
    json['repository'][:original_path] = self.archive.url(:original)
    json['repository'][:little_path] = self.archive.url(:little)
    json['repository'][:medium_path] = self.archive.url(:medium)
    json['repository'][:mini_path] = self.archive.url(:mini)
    json['repository'][:thumb_path] = self.archive.url(:thumb)
    json
  end

  def self.import attrs, options={}
    return attrs.each{|attr| self.import attr, options } if attrs.is_a? Array

    attrs = attrs.dup
    attrs = attrs['repository'] if attrs.has_key? 'repository'

    attrs.except!('id', 'created_at', 'updated_at', 'deleted_at', 'site_id', 'type')

    repository = self.create!(attrs)

  end

  private
  def need_reprocess?
    image? and not has_all_formats?
  end

  def has_all_formats?
    STYLES.each_key do |format|
      return false unless exists_archive?(format)
    end
    true
  end

  def exists_archive?(format=nil)
    FileTest.exist?(archive.path(format))
  end

end
