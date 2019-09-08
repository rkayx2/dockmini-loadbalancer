module CreateTableContainers

import SearchLight.Migration: create_table, column, primary_key, add_index, drop_table

function up()
  create_table(:containers) do
    [
      primary_key()
      column(:image, :string, limit = 255)
      column(:instance, :integer)
      column(:port, :integer)
      column(:requests, :integer)
    ]
  end

  add_index(:containers, :image)
  add_index(:containers, :port)
  add_index(:containers, :requests)
end

function down()
  drop_table(:containers)
end

end
