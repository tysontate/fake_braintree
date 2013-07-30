require 'spec_helper'

describe 'Braintree::CreditCard.find' do
  it 'gets the correct credit card' do
    month = '04'
    year = '2016'
    credit_card = Braintree::CreditCard.find(token_for(month, year))

    credit_card.bin.should == TEST_CC_NUMBER[0, 6]
    credit_card.card_type.should == "FakeBraintree"
    credit_card.last_4.should == TEST_CC_NUMBER[-4,4]
    credit_card.expiration_month.should == month
    credit_card.expiration_year.should ==  year
    credit_card.unique_number_identifier.should == TEST_CC_NUMBER
  end

  def token_for(month, year)
    braintree_credit_card_token(TEST_CC_NUMBER, [month, year].join('/'))
  end
end

describe 'Braintree::CreditCard.sale' do
  it 'successfully creates a sale' do
    result = Braintree::CreditCard.sale(cc_token, amount: 10.00)
    result.should be_success
    Braintree::Transaction.find(result.transaction.id).should be
  end
end


describe 'Braintree::CreditCard.create' do
  it 'allows creating a credit card without a customer' do
    result = Braintree::CreditCard.create(build_credit_card_hash)
    result.should be_success
    Braintree::CreditCard.find('token').should_not be_nil
  end

  context 'with a customer' do
    before do
      @customer = Braintree::Customer.create.customer
    end

    it 'fails to create a credit card if decline_all_cards is set' do
      FakeBraintree.decline_all_cards!
      result = Braintree::CreditCard.create(build_credit_card_hash)
      result.should_not be_success
      expect { Braintree::CreditCard.find('token') }.to raise_error Braintree::NotFoundError
      FakeBraintree.clear!
    end

    it 'fails to create a credit card if verify_all_cards is set and card is invalid' do
      FakeBraintree.verify_all_cards!
      result = Braintree::CreditCard.create(build_credit_card_hash.merge(number: '12345'))
      result.should_not be_success
      expect { Braintree::CreditCard.find('token') }.to raise_error Braintree::NotFoundError
      FakeBraintree.verify_all_cards = false
    end

    it 'successfully creates a credit card' do
      result = Braintree::CreditCard.create(build_credit_card_hash)
      result.should be_success
      Braintree::Customer.find(@customer.id).credit_cards.last.token.should == 'token'
      Braintree::Customer.find(@customer.id).credit_cards.last.should be_default
      Braintree::Customer.find(@customer.id).credit_cards.last.billing_address.postal_code.should == "94110"
    end

    it 'only allows one credit card to be default' do
      result = Braintree::CreditCard.create(build_credit_card_hash)
      result.should be_success
      result = Braintree::CreditCard.create(build_credit_card_hash)
      result.should be_success
      # Reload the customer
      @customer = Braintree::Customer.find(@customer.id)
      @customer.credit_cards.select(&:default?).length.should == 1
      @customer.credit_cards.length.should == 2
    end
  end

  def build_credit_card_hash
    {
      customer_id: @customer && @customer.id,
      number: '4111111111111111',
      cvv: '123',
      token: 'token',
      expiration_date: '07/2020',
      billing_address: {
        postal_code: '94110'
      },
      options: {
        make_default: true
      }
    }
  end
end

describe 'Braintree::CreditCard.update' do
  it 'successfully updates the credit card' do
    new_expiration_date = '08/2012'
    token = cc_token

    result = Braintree::CreditCard.update(token, expiration_date: new_expiration_date)
    result.should be_success
    Braintree::CreditCard.find(token).expiration_date.should == new_expiration_date
  end

  it 'raises an error for a nonexistent credit card' do
    expect { Braintree::CreditCard.update('foo', number: TEST_CC_NUMBER) }.to raise_error(Braintree::NotFoundError)
  end
end
