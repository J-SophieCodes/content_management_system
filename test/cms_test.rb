ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    create_document "about.md", "# Welcome!"
    create_document "changes.txt", "Ruby 0.95 released"
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { login: "admin" } }
  end

  def test_signin_form
    get "/users/login"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_index_signed_in
    get "/", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit")
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_index_signed_out
    get "/"
    assert_includes last_response.body, "Sign In"
  end

  
  def test_valid_login
    post "/users/login", username: "admin", password: "testing"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:login]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_invalid_login
    post "/users/login", username: "admin", password: "1234"
    assert_equal 422, last_response.status
    assert_nil session[:login]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_logout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/logout"
    assert_equal "You have successfully logged out.", session[:message]

    get last_response["Location"]
    assert_nil session[:login]
    assert_includes last_response.body, "Sign In"
  end

  def test_document_not_found
    get '/hello.txt'
    assert_equal 302, last_response.status
    assert_equal "hello.txt does not exist.", session[:message]
  end

  def test_viewing_text_document
    get '/changes.txt' 
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_viewing_markdown_document
    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Welcome!</h1>"
  end

  def test_editing_document
    get "/changes.txt/edit", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_document_signed_out
    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    post "/changes.txt", {content: "new content"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "'changes.txt' has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_updating_document_signed_out
    post "/changes.txt", content: "new content"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_signed_out
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_submit_new_document
    post "/new", {filename: "new.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "'new.txt' has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "new.txt"
  end

  def test_submit_new_document_signed_out
    post "/new", {filename: "new.txt"}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_submit_new_document_without_filename
    post "/new", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_delete_document
    post "/about.md/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "'about.md' has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/about.md")
  end

  def test_delete_document_signed_out
    post "/about.md/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end