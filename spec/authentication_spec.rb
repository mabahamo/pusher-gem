require File.expand_path('../spec_helper', __FILE__)

describe Authentication do
  before :each do
    Time.stub!(:now).and_return(Time.at(1234))

    @token = Authentication::Token.new('key', 'secret')

    @request = Authentication::Request.new('/some/path', {
      "query" => "params",
      "go" => "here"
    })
    @signature = @request.sign(@token)[:signature]
  end

  it "should generate base64 encoded signature from correct key" do
    @request.send(:string_to_sign).should == "/some/path\ngo=here&key=key&query=params&timestamp=1234"
    @signature.should == 'HFGEMrVtuoawgUD0WDTAM/x0bQ6H56uX/tt51zSrZO8='
  end

  it "should make auth_hash available after request is signed" do
    request = Authentication::Request.new('/some/path', {
      "query" => "params"
    })
    lambda {
      request.auth_hash
    }.should raise_error('Request not signed')

    request.sign(@token)
    request.auth_hash.should == {
      :signature=>"RKsOVCCUodmL4GyT44BNa1zVqPB1/UlnhTdg2owdRHQ=",
      :key=>"key",
      :timestamp=>1234
    }
  end

  it "should cope with symbol keys" do
    @request.query_hash = {
      :query => "params",
      :go => "here"
    }
    @request.sign(@token)[:signature].should == @signature
  end

  it "should cope with upcase keys (keys are lowercased before signing)" do
    @request.query_hash = {
      "Query" => "params",
      "GO" => "here"
    }
    @request.sign(@token)[:signature].should == @signature
  end

  it "should use the path to generate signature" do
    @request.path = '/some/other/path'
    @request.sign(@token)[:signature].should_not == @signature
  end

  it "should use the query string keys to generate signature" do
    @request.query_hash = {
      "other" => "query"
    }
    @request.sign(@token)[:signature].should_not == @signature
  end

  it "should use the query string values to generate signature" do
    @request.query_hash = {
      "key" => "notfoo",
      "other" => 'bar'
    }
    @request.sign(@token)[:signature].should_not == @signature
  end

  it "should also hash the body if included" do
    @request.body = 'some body text'
    @request.send(:string_to_sign).should == "/some/path\ngo=here&key=key&query=params&timestamp=1234\nsome body text"
    @request.sign(@token)[:signature].should_not == @signature
  end

  it "should verify requests" do
    auth_hash = @request.sign(@token)
    params = @request.query_hash.merge(auth_hash)

    request_to_verify = Authentication::Request.new(@request.path, params)
    request_to_verify.authenticate(@token).should == true
  end
end
