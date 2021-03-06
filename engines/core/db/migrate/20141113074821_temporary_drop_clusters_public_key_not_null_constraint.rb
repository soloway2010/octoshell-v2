class TemporaryDropClustersPublicKeyNotNullConstraint < ActiveRecord::Migration
  def change
    change_column_null :core_clusters, :public_key, true
    change_column_null :core_clusters, :private_key, true
    change_column_null :core_clusters, :admin_login, true
  end
end
