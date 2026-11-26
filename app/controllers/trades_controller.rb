# The dashboard's trades table, loaded into its own Turbo Frame.
class TradesController < ApplicationController
  include Pagy::Method

  PER_PAGE = 25
  # Only these can be sorted on: the request never names a column itself.
  SORTS = {
    "closed_at" => Trade.arel_table[:closed_at],
    "opened_at" => Trade.arel_table[:opened_at],
    "symbol" => Trade.arel_table[:symbol],
    "side" => Trade.arel_table[:side],
    "volume" => Trade.arel_table[:volume],
    "net_profit" => Trade.arel_table[:net_profit],
    "robot" => Robot.arel_table[:name]
  }.freeze
  DEFAULT_SORT = "closed_at"

  def index
    @account = Account.visible_to(Current.user).find(params[:account_id])
    @filter = Metrics::Filter.from_params(@account, params)
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @direction = params[:direction] == "asc" ? "asc" : "desc"
    @pagy, @trades = pagy(:offset, sorted_trades, limit: PER_PAGE)
  end

  private
    # The position id breaks ties, so pages never overlap.
    def sorted_trades
      order = SORTS.fetch(@sort).public_send(@direction).nulls_last
      scope = @filter.trades.includes(:robot).order(order, position_id: @direction)
      @sort == "robot" ? scope.left_joins(:robot) : scope
    end
end
