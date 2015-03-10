module Spree
  class CcavenueController < StoreController

    skip_before_filter :verify_authenticity_token, only: :callback # Request to callback comes from CCAvenue, so it does not contain authenticity token

    helper 'spree/orders'
    ssl_allowed

    # This action prepares necessary attributes required by CCAvenue
    def show

      @payment_method = Spree::PaymentMethod.find(params[:payment_method_id])
      if !@payment_method or !@payment_method.kind_of?(Spree::Ccavenue::PaymentMethod)
        flash[:error] = 'Invalid payment method for this transaction'
        render :error
        return
      end

      @order = current_order
      if @order.has_authorized_ccavenue_transaction?
        flash[:error] = "Order #{@order.number} is already authorized at CCAvenue"
        render :error
        return
      end

      # Precautions
      @order.cancel_existing_ccavenue_transactions!
      @order.payments.destroy_all

      # Creating new payment and transaction based on Spree::Order
      @order.payments.build(:amount => @order.total, :payment_method_id => @payment_method.id)
      @transaction = @order.ccavenue_transactions.build(:amount => @order.total,
                                                        :currency => @order.currency.to_s,
                                                        :payment_method_id => @payment_method.id)

      @transaction.transact

      # added by abhi on 14th feb for ccavenue response handling  
  if ResponseHandler.exists?(:user_id => spree_current_user.id)
  puts "inside if--------------------------"
  ResponseHandler.where(:user_id => spree_current_user.id).delete_all
  # create_response_handler = "INSERT INTO response_handlers (user_id,transaction_id) VALUES ('#{spree_current_user.id},'#{trid}')"
  # puts create_response_handler
  ResponseHandler.create([{:user_id => spree_current_user.id,:transaction_id => "#{@transaction.id}"}])
  # ResponseHandler.connection.execute(create_response_handler)
else
  puts "Inside else----------------------------"
  # create_response_handler = "INSERT INTO response_handlers (user_id,transaction_id) VALUES ('#{spree_current_user.id},'#{trid}')"
   # puts create_response_handler
  # ResponseHandler.connection.execute(create_response_handler)
  ResponseHandler.create([{:user_id => spree_current_user.id,:transaction_id => "#{@transaction.id}"}])
end


      @order.save!
      logger.info("Sending order #{@order.number} to CCAvenue via transaction id #{@transaction.id}")
      #@bill_address, @ship_address = @order.bill_address, (@order.ship_address || @order.bill_address)
      @bill_address  = @order.bill_address
      @ship_address  = @order.bill_address
    end

    # Handles CCAvenue response which contains info about payment status
    def callback
      #added by Nitin for transaction id from ResponseHandler - on 4th Mar 2015
      trid = ResponseHandler.where(:user_id => spree_current_user.id).pluck(:transaction_id).last

        puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#{@tid}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      @transaction = Spree::Ccavenue::Transaction.find(trid)

        puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#{@transaction}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

      raise "Transaction with id: #{trid} not found!" unless @transaction


      params = decrypt_ccavenue_response_params # Need to decrypt params first
      logger.info "Decrypted params from CCAvenue #{params.inspect}"
      @transaction.auth_desc = params['order_status']
      @transaction.card_category = params['card_name']
      @transaction.ccavenue_order_number = params['order_id']
      @transaction.ccavenue_amount = params['amount']
      failure_message = params['failure_message']
      status_message = params['status_message ']

      session[:access_token] = @transaction.order.guest_token if @transaction.order.respond_to?(:guest_token)
      session[:order_id] = @transaction.order.id

      if @transaction.next
        # Handling of possible transaction states, check CCAvenue documentation for details
        if @transaction.authorized? # Successful
          session[:order_id] = nil
          flash.notice = I18n.t(:order_processed_successfully)
          flash[:commerce_tracking] = 'nothing special'
          # We are setting token here so that even if the URL is copied and reused later on he completed order page still gets displayed
          if session[:access_token].nil?
            redirect_to order_path(@transaction.order, {:checkout_complete => true})
          else
            redirect_to order_path(@transaction.order, {:checkout_complete => true, :token => session[:access_token]})
          end
        elsif @transaction.rejected?
          redirect_to edit_order_path(@transaction.order), :error => I18n.t("payment_rejected")
        elsif @transaction.canceled?
          redirect_to edit_order_path(@transaction.order), :notice => I18n.t("payment_canceled")
        elsif @transaction.initiated?
          redirect_to edit_order_path(@transaction.order), :notice => I18n.t("payment_initiated")
        elsif @transaction.batch?
          # Don't allow the order to be reused.
          session[:order_id] = nil
          render 'batch'
        end
      else
        render 'error'
      end
    end

    private

    def decrypt_ccavenue_response_params
      logger.info "Received transaction from CCAvenue #{params.inspect}"
      encryption_key = @transaction.payment_method.preferred_encryption_key
      query = AESCrypter.decrypt(params['encResp'], encryption_key)
      Rack::Utils.parse_nested_query(query)
    end
  end
end
