defmodule MediaStream.Repo.Migrations.CreateAudioFilesAndPlaybackStates do
  use Ecto.Migration

  def change do
    create table(:audio_files) do
      add :path, :string, null: false
      add :title, :string
      add :artist, :string
      add :album, :string
      add :duration_seconds, :integer
      add :file_type, :string
      add :file_size, :integer

      timestamps()
    end

    create unique_index(:audio_files, [:path])
    create index(:audio_files, [:title])
    create index(:audio_files, [:artist])
    create index(:audio_files, [:album])

    create table(:playback_states) do
      add :device_id, :string, null: false
      add :current_file_id, references(:audio_files, on_delete: :nilify_all)
      add :position_seconds, :float, default: 0.0
      add :queue_json, :text

      timestamps()
    end

    create unique_index(:playback_states, [:device_id])
    create index(:playback_states, [:current_file_id])
  end
end
