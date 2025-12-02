defmodule MediaStream.Repo.Migrations.CreateListeningHistory do
  use Ecto.Migration

  def change do
    create table(:listening_history) do
      add :audio_file_id, references(:audio_files, on_delete: :delete_all), null: false
      add :device_id, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :duration_listened_seconds, :integer, default: 0

      timestamps()
    end

    create index(:listening_history, [:audio_file_id])
    create index(:listening_history, [:device_id])
    create index(:listening_history, [:started_at])
    create index(:listening_history, [:completed_at])
  end
end
