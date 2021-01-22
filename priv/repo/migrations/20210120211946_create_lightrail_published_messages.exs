defmodule Test.Support.Repo.Migrations.CreateLightrailPublishedMessages do
  use Ecto.Migration

  def change do

    create table(:lightrail_published_messages, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :message_type, :string, null: false
      add :user_uuid, :uuid
      add :correlation_id, :uuid
      add :encoded_message, :text
      add :status, :string, null: false
      add :exchange, :string

      timestamps()
    end
  end
end
