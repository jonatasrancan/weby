require "rails_helper"

describe Admin::SitesController do
  let(:user) { FactoryGirl.create(:user, is_admin: true) }
  let(:locale) { FactoryGirl.create(:locale) }
  let!(:first_site) { Site.create(:name => "site", :title => "Site", :url => "http://site.lvh.me") }

  before { sign_in user }

  describe "GET #index" do
    before { get :index }

    skip "assigns @sites" do
      expect(assigns(:sites)).to eq([first_site])
    end

    it "renders the :index view" do
      expect(response).to render_template(:index)
    end
  end

  describe "GET #new" do
    before { get :new }

    it "assigns @site" do
      expect(assigns(:site)).to be_a_new(Site)
    end

    it "renders the :new view" do
      expect(response).to render_template(:new)
    end
  end

  describe "GET #edit" do
    before { get :edit, :id => first_site.id }

    skip "assigns @site" do
      expect(assigns(:site)).to eq(first_site)
    end

    skip "renders the :edit template" do
      expect(response).to render_template(:edit)
    end
  end

  describe "POST #create" do
    context "when valid" do
      before { post :create, :post => { name: "test_site", title: "Test Site",
                                        url: "http://testsite.lvh.me" } }

      skip "will redirect to site_admin_components path" do
        expect(response).to redirect_to(site_admin_components_path(subdomain: first_site))
      end
    end

    context "when invalid" do
      before { post :create, site: { name: "", title: "", url: "http://testsite.lvh.me" } }

      it "will render :new view" do
        expect(response).to render_template(:new)
      end
    end
  end

  describe "PUT #update" do
    context "when valid" do
      before { post :create, :post => { :name => "test", :title => "Test",
                                        :url => "http://test.lvh.me"  } }

      skip "will redirect to edit path" do
        expect(response).to redirect_to(edit_admin_site_url(first_site.id))
      end
    end

    context "when invalid" do
      before { post :create, :post => { :name => "", :title => "", :url => "" } }

      skip "will render :edit view" do
        expect(response).to render_template(:edit)
      end
    end
  end

  ## private ##

  skip "sort_column" do
  end

  skip "load_themes" do
  end
end
