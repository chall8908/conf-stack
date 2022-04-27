# frozen_string_literal: true

RSpec.describe Masterplan do
  it "has a version number" do
    expect(Masterplan::VERSION).not_to be nil
  end

  context 'Custom Attributes' do
    before { described_class.add_attribute(:test_attribute) }
    let(:config) { described_class.new }

    it 'creates a getter for the custom attribute' do
      expect(config).to respond_to :test_attribute
    end

    it 'creates a setter for the custom attribute' do
      expect(config).to respond_to :'test_attribute='
    end

    it 'creates a checker for the custom attribute' do
      expect(config).to respond_to :'test_attribute?'
    end

    it 'only allows a custom attribute to be set once' do
      config.test_attribute = 'expected'
      config.test_attribute = 'ignored'

      expect(config.test_attribute).to eq 'expected'
    end

    it 'latches false' do
      config.test_attribute = false
      config.test_attribute = 'ignored'

      expect(config.test_attribute).to eq false
    end

    context 'callable values' do
      let(:mock_proc) { Proc.new do; end }

      before { config.test_attribute = mock_proc }

      it 'evaluates callable attributes with instance eval' do
        expect(config).to receive(:instance_eval).and_return('expected')

        expect(config.test_attribute).to eq 'expected'
      end

      it 'caches the value returned by the callable' do
        expect(config).to receive(:instance_eval).once.and_return('expected')

        config.test_attribute
        config.test_attribute
      end
    end

    it 'throws a MissingConfigurationError when configuration is missing' do
      expect { config.not_set }.to raise_error(Masterplan::MissingConfigurationError)
    end
  end

  context 'DSL' do
    let(:config) { described_class.new }
    let(:dsl) { described_class::DSL.new config, '' }

    context '#configure' do
      it 'creates a method on the configuration object' do
        dsl.configure(:test)

        expect(config).to respond_to(:test)
      end

      it 'accepts a hash as the key: value' do
        dsl.configure(test: 'foo')

        expect(config.test).to eq 'foo'
      end
    end

    context 'backward compatability' do
      it 'allows Mastermind-specific methods' do
        expect(dsl).to respond_to(:plan_files)
        expect(dsl).to respond_to(:has_plan_files)
        expect(dsl).to respond_to(:plan_file)
        expect(dsl).to respond_to(:define_alias)
        expect(dsl).to respond_to(:skip_confirmation)
      end
    end
  end
end
