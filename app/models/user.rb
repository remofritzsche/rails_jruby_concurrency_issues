class User < ApplicationRecord
  belongs_to :group
  has_one :managed_group, class_name: 'Group'
end
