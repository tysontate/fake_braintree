require 'sinatra/base'

module FakeBraintree
  class SinatraApp < Sinatra::Base
    set :show_exceptions, false
    set :dump_errors, true
    set :raise_errors, true
    disable :logging

    include Helpers

    # Braintree::Customer.create
    post "/merchants/:merchant_id/customers" do
      customer_hash = Hash.from_xml(request.body).delete("customer")
      options = {:merchant_id => params[:merchant_id]}
      Customer.new(customer_hash, options).create
    end

    # Braintree::Customer.find
    get "/merchants/:merchant_id/customers/:id" do
      customer = FakeBraintree.customers[params[:id]]
      if customer
        gzipped_response(200, customer.to_xml(:root => 'customer'))
      else
        gzipped_response(404, {})
      end
    end

    # Braintree::Customer.update
    put "/merchants/:merchant_id/customers/:id" do
      customer_hash = Hash.from_xml(request.body).delete("customer")
      options = {:id => params[:id], :merchant_id => params[:merchant_id]}
      Customer.new(customer_hash, options).update
    end

    # Braintree::Subscription.create
    post "/merchants/:merchant_id/subscriptions" do
      subscription_hash = Hash.from_xml(request.body).delete("subscription")
      options = {:merchant_id => params[:merchant_id]}
      Subscription.new(subscription_hash, options).create
    end

    # Braintree::Subscription.find
    get "/merchants/:merchant_id/subscriptions/:id" do
      subscription = FakeBraintree.subscriptions[params[:id]]
      if subscription
        gzipped_response(200, subscription.to_xml(:root => 'subscription'))
      else
        gzipped_response(404, {})
      end
    end

    # Braintree::CreditCard.find
    get "/merchants/:merchant_id/payment_methods/:credit_card_token" do
      credit_card = FakeBraintree.credit_card_from_token(params[:credit_card_token])
      gzipped_response(200, credit_card.to_xml(:root => "credit_card"))
    end

    # Braintree::Transaction.sale
    # Braintree::CreditCard.sale
    post "/merchants/:merchant_id/transactions" do
      if FakeBraintree.decline_all_cards?
        gzipped_response(422, FakeBraintree.create_failure.to_xml(:root => 'api_error_response'))
      else
        transaction          = Hash.from_xml(request.body)["transaction"]
        transaction_id       = md5("#{params[:merchant_id]}#{Time.now.to_f}")
        transaction_response = {"id" => transaction_id, "amount" => transaction["amount"]}
        FakeBraintree.transactions[transaction_id] = transaction_response
        gzipped_response(200, transaction_response.to_xml(:root => "transaction"))
      end
    end

    # Braintree::Transaction.find
    get "/merchants/:merchant_id/transactions/:transaction_id" do
      transaction = FakeBraintree.transactions[params[:transaction_id]]
      if transaction
        gzipped_response(200, transaction.to_xml(:root => "transaction"))
      else
        gzipped_response(404, {})
      end
    end

    # Braintree::TransparentRedirect.url
    post "/merchants/:merchant_id/transparent_redirect_requests" do
      if params[:tr_data]
        redirect = Redirect.new(params, params[:merchant_id])
        FakeBraintree.redirects[redirect.id] = redirect
        redirect to(redirect.url), 303
      else
        [422, { "Content-Type" => "text/html" }, ["Invalid submission"]]
      end
    end

    # Braintree::TransparentRedirect.confirm
    post "/merchants/:merchant_id/transparent_redirect_requests/:id/confirm" do
      redirect = FakeBraintree.redirects[params[:id]]
      redirect.confirm
    end
  end
end
