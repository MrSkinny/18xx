# frozen_string_literal: true

require_relative '../../../step/buy_train'

module Engine
  module Game
    module GSystem18
      module Step
        class BuyTrain < Engine::Step::BuyTrain
          def setup
            @emr_issue = false
            super
          end

          def process_sell_shares(action)
            return super unless action.entity == current_entity
            raise GameError, "Cannot sell shares of #{action.bundle.corporation.name}" unless can_sell?(action.entity,
                                                                                                        action.bundle)

            @emr_issue = true
            @game.sell_shares_and_change_price(action.bundle, movement: :left_share)
          end

          def process_buy_train(action)
            super
            @emr_issue = false
          end

          def other_trains(entity)
            return super unless @emr_issue

            []
          end
        end
      end
    end
  end
end
