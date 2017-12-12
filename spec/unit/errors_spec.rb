# frozen_string_literal: true

require 'spec_helper'

describe 'CloudFoundry::Perm::V1::Errors' do
  describe '.from_grpc_error' do
    it 'transforms GRPC::AlreadyExists errors into Errors::AlreadyExists' do
      err = CloudFoundry::Perm::V1::Errors.from_grpc_error(GRPC::AlreadyExists.new('some-error', 'some-metadata'))

      expect(err).to be_a(CloudFoundry::Perm::V1::Errors::AlreadyExists)
      expect(err.details).to eq('some-error')
      expect(err.metadata).to eq('some-metadata')
    end

    it 'transforms GRPC::NotFound errors into Errors::NotFound' do
      err = CloudFoundry::Perm::V1::Errors.from_grpc_error(GRPC::NotFound.new('some-error', 'some-metadata'))

      expect(err).to be_a(CloudFoundry::Perm::V1::Errors::NotFound)
      expect(err.details).to eq('some-error')
      expect(err.metadata).to eq('some-metadata')
    end

    it 'transforms GRPC::BadStatus errors into Errors::BadStatus' do
      err = CloudFoundry::Perm::V1::Errors.from_grpc_error(GRPC::BadStatus.new('some-code', 'some-error', 'some-metadata'))

      expect(err).to be_a(CloudFoundry::Perm::V1::Errors::BadStatus)
      expect(err.code).to eq('some-code')
      expect(err.details).to eq('some-error')
      expect(err.metadata).to eq('some-metadata')
    end

    it 'leaves all other errors alone' do
      err = CloudFoundry::Perm::V1::Errors.from_grpc_error(StandardError.new('some-message'))

      expect(err).not_to be_a(CloudFoundry::Perm::V1::Errors::StandardError)
      expect(err).to be_a(::StandardError)
    end
  end
end
