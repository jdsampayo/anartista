defmodule AnartistaWeb.AdminSessionControllerTest do
  use AnartistaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Anartista.Accounts
  alias Anartista.Accounts.UserToken
  alias Anartista.Repo

  @password "admin-test-password"

  setup do
    {:ok, user} =
      Accounts.create_user(%{
        email: "admin-#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    %{user: user}
  end

  test "valid credentials establish a session and permit admin access", %{conn: conn, user: user} do
    conn =
      post(conn, ~p"/admin/login", %{
        "user" => %{"email" => "  #{String.upcase(user.email)}  ", "password" => @password}
      })

    assert redirected_to(conn) == "/admin"
    token = get_session(conn, :user_token)
    assert Accounts.get_user_by_session_token(token).id == user.id

    conn = conn |> recycle() |> get(~p"/admin")
    assert conn.status == 200
  end

  test "login returns to each requested admin page and clears prelogin session data", %{
    user: user
  } do
    for path <- [
          ~p"/admin",
          ~p"/admin/store",
          ~p"/admin/messages",
          ~p"/admin/exhibitions",
          ~p"/admin/obra"
        ] do
      conn =
        build_conn()
        |> init_test_session(prelogin_baggage: "discard me")
        |> get(path)

      assert redirected_to(conn) == "/admin/login"
      assert get_session(conn, :user_return_to) == path

      conn =
        conn
        |> recycle()
        |> post(~p"/admin/login", %{
          "user" => %{"email" => user.email, "password" => @password}
        })

      assert redirected_to(conn) == path
      assert get_session(conn, :prelogin_baggage) == nil
      assert get_session(conn, :user_return_to) == nil
      assert Accounts.get_user_by_session_token(get_session(conn, :user_token)).id == user.id
    end
  end

  test "login refuses return destinations outside the exact admin allowlist", %{user: user} do
    for path <- [
          "https://example.com/steal-session",
          "//example.com/admin",
          "/admin/unknown",
          "/admin/login",
          "/admin/store?next=https://example.com",
          "/admin/exhibitions/../store",
          "/admin/obra?next=https://example.com",
          "/admin/obra/../store",
          "/admin/"
        ] do
      conn =
        build_conn()
        |> init_test_session(user_return_to: path)
        |> post(~p"/admin/login", %{
          "user" => %{"email" => user.email, "password" => @password}
        })

      assert redirected_to(conn) == "/admin"
      assert get_session(conn, :user_return_to) == nil
    end
  end

  test "unknown users and wrong passwords receive the same error without exposing passwords", %{
    user: user
  } do
    errors =
      for email <- [user.email, "unknown@example.com"] do
        password = "wrong-secret-never-render"

        conn =
          post(build_conn(), ~p"/admin/login", %{
            "user" => %{"email" => email, "password" => password}
          })

        html = html_response(conn, 200)
        [error] = html |> Floki.parse_document!() |> Floki.find("[role=alert]")
        refute html =~ password
        assert get_session(conn, :user_token) == nil
        Floki.text(error)
      end

    assert [wrong_password_error, unknown_user_error] = errors
    assert wrong_password_error == unknown_user_error
  end

  test "authenticated visitors to login are redirected to the admin dashboard", %{conn: conn} do
    conn = conn |> register_and_log_in_user() |> get(~p"/admin/login")

    assert redirected_to(conn) == "/admin"
  end

  test "logout revokes the token, disconnects live sessions and removes session data", %{
    conn: conn,
    user: user
  } do
    conn =
      post(conn, ~p"/admin/login", %{
        "user" => %{"email" => user.email, "password" => @password}
      })

    token = get_session(conn, :user_token)
    topic = get_session(conn, :live_socket_id)
    assert is_binary(topic)
    :ok = Phoenix.PubSub.subscribe(Anartista.PubSub, topic)

    session = Map.put(get_session(conn), "private_baggage", "discard me")
    conn = conn |> recycle() |> init_test_session(session) |> delete(~p"/admin/logout")

    assert redirected_to(conn) == "/admin/login"
    assert Accounts.get_user_by_session_token(token) == nil
    assert get_session(conn, :user_token) == nil
    assert get_session(conn, :live_socket_id) == nil
    assert get_session(conn, :private_baggage) == nil
    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect"}

    conn = conn |> recycle() |> get(~p"/admin/messages")
    assert redirected_to(conn) == "/admin/login"
  end

  test "revoked session cookies cannot access administration", %{conn: conn, user: user} do
    token = Accounts.generate_user_session_token(user)
    :ok = Accounts.delete_user_session_token(token)

    conn = conn |> init_test_session(user_token: token) |> get(~p"/admin/store")

    assert redirected_to(conn) == "/admin/login"
  end

  test "expired session cookies cannot access administration", %{conn: conn, user: user} do
    token = Accounts.generate_user_session_token(user)
    expired_at = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -8, :day)
    Repo.update_all(UserToken, set: [inserted_at: expired_at])

    conn = conn |> init_test_session(user_token: token) |> get(~p"/admin/messages")

    assert redirected_to(conn) == "/admin/login"
  end

  test "malformed and unknown session tokens are refused without crashing" do
    for token <- ["not-a-token", %{"unexpected" => "value"}, :crypto.strong_rand_bytes(32)] do
      conn = build_conn() |> init_test_session(user_token: token) |> get(~p"/admin/store")

      assert redirected_to(conn) == "/admin/login"
      assert get_resp_header(conn, "www-authenticate") == []
    end
  end

  test "a Basic authorization header alone does not grant admin access", %{conn: conn, user: user} do
    conn =
      conn
      |> put_req_header("authorization", "Basic " <> Base.encode64("#{user.email}:#{@password}"))
      |> get(~p"/admin/messages")

    assert redirected_to(conn) == "/admin/login"
    assert get_resp_header(conn, "www-authenticate") == []
  end

  test "invalid administrator cookies do not protect the public site" do
    for path <- [~p"/", ~p"/about", ~p"/obra", ~p"/exhibitions", ~p"/writing", ~p"/contact"] do
      conn = build_conn() |> init_test_session(user_token: "invalid") |> get(path)
      assert conn.status == 200
    end
  end

  test "connected admin mounts recheck a token revoked after the HTTP render", %{user: user} do
    for path <- [
          ~p"/admin",
          ~p"/admin/store",
          ~p"/admin/messages",
          ~p"/admin/exhibitions",
          ~p"/admin/obra"
        ] do
      token = Accounts.generate_user_session_token(user)
      conn = build_conn() |> init_test_session(user_token: token) |> get(path)
      assert conn.status == 200

      :ok = Accounts.delete_user_session_token(token)

      assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn)
    end
  end
end
